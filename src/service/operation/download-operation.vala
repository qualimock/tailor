/* DownloadOperation.vala
 *
 * Copyright 2026 Алексей Волков <$email>
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

		private OsImage image;
		private Soup.Session session;
		private FileIOStream? iostream = null;

		private int64 last_bytes = 0;
		private uint stall_timeout_id = 0;

		private bool stalled = false;

		public signal void completed (File temp_file);

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
			start_stall_timer ();
		}

		public override async void run_async () throws Error {
			if (image.url == null)
				throw new IOError.INVALID_ARGUMENT ("OS has no download URL");

			state = State.DOWNLOADING;

			var tmp_file = yield create_temp_file ();

			try {
				var input = yield open_source ();

				yield stream (input);

				yield iostream.close_async (Priority.DEFAULT, null);
				completed (tmp_file);
			} catch (Error e) {
				stop_stall_timer ();

				yield iostream.close_async (Priority.DEFAULT, null);
				tmp_file.delete_async.begin (Priority.DEFAULT, null, null);

				if (!(e is IOError.CANCELLED) || stalled)
					failed (stalled ? _("Connection lost") : e.message);

				throw e;
			}
		}

		private void start_stall_timer () {
			stall_timeout_id = Timeout.add_seconds (10, () => {
				if (bytes_written == last_bytes) {
					stall_timeout_id = 0;
					stalled = true;
					cancellable.cancel ();
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

		private async File create_temp_file () throws Error {
			return yield File.new_tmp_async (
				"tailor-XXXXXX.iso",
				Priority.DEFAULT,
				cancellable,
				out iostream
			);
		}

		private async InputStream open_source () throws Error {
			var msg = new Soup.Message ("GET", image.url);
			msg.request_headers.append ("Accept", "*/*");
			var input = yield session.send_async (msg, Priority.DEFAULT, cancellable);

			if (msg.status_code != Soup.Status.OK)
				throw new IOError.FAILED ("HTTP %u: %s".printf (msg.status_code, msg.reason_phrase));

			total_bytes = msg.response_headers.get_content_length ();
			return input;
		}

		private async void stream (InputStream input) throws Error {
			var output = iostream.output_stream;
			var buf = new uint8[1024 * 1024];
			ssize_t n;

			start_stall_timer ();

			while ((n = yield input.read_async (buf, Priority.DEFAULT, cancellable)) > 0) {
				if (paused)
					yield wait_for_resume ();

				size_t written;
				yield output.write_all_async (
					buf[0:n],
					Priority.DEFAULT,
					cancellable,
					out written
				);

				bytes_written += written;

				progress (bytes_written, total_bytes);
			}

			stop_stall_timer ();
		}
	}
}
