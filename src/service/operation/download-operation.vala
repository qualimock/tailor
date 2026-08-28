/* download-operation.vala
 *
 * Copyright 2026 Alexey Volkov <qualimock@altlinux.org>
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

namespace Tailor {

	public class DownloadOperation : Operation {

		private const int MAX_RETRIES = 3;

		private OsImage image;
		private Soup.Session session;
		private FileIOStream? iostream = null;

		private int64 last_bytes = 0;
		private uint stall_timeout_id = 0;

		private bool stalled = false;
		private Cancellable? current_attempt_cancellable = null;

		public signal void completed (File temp_file);
		public signal void skipped (File existing_file);

		public DownloadOperation (OsImage image, Cancellable cancellable) {
			this.image = image;
			this.cancellable = cancellable;

			session = new Soup.Session ();
			session.timeout = 30;
			session.user_agent = @"$(Tailor.ID)/$(Tailor.VERSION)";
		}

		public override void pause () {
			base.pause ();
			stop_stall_timer ();
		}

		public override void resume () {
			base.resume ();
			if (current_attempt_cancellable != null)
				start_stall_timer (current_attempt_cancellable);
		}

		public override async void run_async () throws Error {
			if (image.url == null)
				throw new IOError.INVALID_ARGUMENT ("OS has no download URL");

			state = State.DOWNLOADING;

			var existing = yield check_existing ();
			if (existing != null) {
				skipped (existing);
				return;
			}

			var tmp_file = yield create_temp_file ();

			try {
				yield stream_with_retries ();

				yield iostream.close_async (Priority.DEFAULT, null);

				var dest = yield move_to_cache (tmp_file);
				completed (dest);
			} catch (Error e) {
				stop_stall_timer ();

				yield iostream.close_async (Priority.DEFAULT, null);
				tmp_file.delete_async.begin (Priority.DEFAULT, null, null);

				if (!(e is IOError.CANCELLED))
					failed (e.message);

				throw e;
			}
		}

		public static File cache_path_for (OsImage image) {
			var cache_dir = Path.build_filename (
				Environment.get_user_cache_dir (), "tailor", "images"
			);

			return File.new_for_path (cache_dir).get_child (Path.get_basename (image.url));
		}

		private async void stream_with_retries () throws Error {
			for (int attempt = 0; ; attempt++) {
				var attempt_cancellable = new Cancellable ();
				current_attempt_cancellable = attempt_cancellable;
				var link_id = cancellable.connect (() => attempt_cancellable.cancel ());

				try {
					var input = yield open_source (attempt_cancellable);
					yield stream (input, attempt_cancellable);
					cancellable.disconnect (link_id);
					return;
				} catch (Error e) {
					cancellable.disconnect (link_id);

					if (cancellable.is_cancelled ())
						throw e;

					if (!stalled)
						throw e;

					stalled = false;

					if (attempt + 1 >= MAX_RETRIES)
						throw new IOError.FAILED (_("Connection lost"));

					progress (0, 0);
					yield sleep_async (5);
				}
			}
		}

		private async void sleep_async (uint seconds) throws Error {
			var timeout_id = Timeout.add_seconds (seconds, sleep_async.callback);
			var cancel_id = cancellable.connect (() => {
				Source.remove (timeout_id);
				Idle.add (sleep_async.callback);
			});
			yield;
			cancellable.disconnect (cancel_id);

			if (cancellable.is_cancelled ())
				throw new IOError.CANCELLED ("Cancelled during retry wait");
		}

		private void start_stall_timer (Cancellable attempt_cancellable) {
			stall_timeout_id = Timeout.add_seconds (10, () => {
				if (bytes_written == last_bytes) {
					stall_timeout_id = 0;
					stalled = true;
					attempt_cancellable.cancel ();
					return Source.REMOVE;
				}
				last_bytes = bytes_written;
				return Source.CONTINUE;
			});
		}

		private void stop_stall_timer () {
			if (stall_timeout_id != 0) {
				Source.remove (stall_timeout_id);
				stall_timeout_id = 0;
				stalled = false;
			}
		}

		private File get_dest_file () {
			return cache_path_for (image);
		}

		private async File? check_existing () throws Error {
			var dest = get_dest_file ();

			if (!dest.query_exists (cancellable))
				return null;

			if (image.checksum != null)
				return (yield image.verify_checksum (dest, cancellable)) ? dest : null;

			return dest;
		}

		private async File move_to_cache (File tmp_file) throws Error {
			var dest = get_dest_file ();

			var cache_dir = dest.get_parent ();
			if (cache_dir != null && !cache_dir.query_exists (cancellable))
				cache_dir.make_directory_with_parents (cancellable);

			yield tmp_file.move_async (dest, FileCopyFlags.OVERWRITE, Priority.DEFAULT, cancellable, null);

			return dest;
		}

		private async File create_temp_file () throws Error {
			return yield File.new_tmp_async (
				"tailor-XXXXXX.iso",
				Priority.DEFAULT,
				cancellable,
				out iostream
			);
		}

		private async InputStream open_source (Cancellable attempt_cancellable) throws Error {
			var msg = new Soup.Message ("GET", image.url);
			msg.request_headers.append ("Accept", "*/*");

			if (bytes_written > 0)
				msg.request_headers.append ("Range", @"bytes=$(bytes_written)-");

			var input = yield session.send_async (msg, Priority.DEFAULT, attempt_cancellable);

			if (bytes_written > 0) {
				if (msg.status_code != Soup.Status.PARTIAL_CONTENT)
					throw new IOError.FAILED ("Server doesn't support resume, HTTP %u".printf (msg.status_code));
			} else {
				if (msg.status_code != Soup.Status.OK)
					throw new IOError.FAILED ("HTTP %u: %s".printf (msg.status_code, msg.reason_phrase));

				total_bytes = msg.response_headers.get_content_length ();
			}

			return input;
		}

		private async void stream (InputStream input, Cancellable attempt_cancellable) throws Error {
			var output = iostream.output_stream;
			var buf = new uint8[1024 * 1024];
			ssize_t n;

			start_stall_timer (attempt_cancellable);

			while ((n = yield input.read_async (buf, Priority.DEFAULT, attempt_cancellable)) > 0) {
				if (paused)
					yield wait_for_resume ();

				size_t written;
				yield output.write_all_async (
					buf[0:n],
					Priority.DEFAULT,
					attempt_cancellable,
					out written
				);

				bytes_written += written;

				progress (bytes_written, total_bytes);
			}

			stop_stall_timer ();
		}
	}
}
