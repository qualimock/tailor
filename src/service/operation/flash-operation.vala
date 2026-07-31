/* flash-operation.vala
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

	public class FlashOperation : Operation {

		private UDisks.Block block;
		private DBusObjectManager object_manager;
		private OsImage? os_image = null;
		private File? image_file = null;
		private DownloadOperation? download_operation = null;
		private bool downloading = false;

		private Checksum source_checksum = new Checksum (ChecksumType.SHA256);

		public signal void completed ();
		public signal void downloaded (File file, bool skipped);

		public FlashOperation.with_file (
			UDisks.Block block,
			DBusObjectManager object_manager,
			File image_file,
			Cancellable cancellable
		) {
			this.block = block;
			this.object_manager = object_manager;
			this.image_file = image_file;
			this.cancellable = cancellable;
		}

		public FlashOperation.with_download (
			UDisks.Block block,
			DBusObjectManager object_manager,
			OsImage os_image,
			Cancellable cancellable
		) {
			this.block = block;
			this.object_manager = object_manager;
			this.os_image = os_image;
			this.download_operation = new DownloadOperation (os_image, cancellable);
			this.cancellable = cancellable;
		}

		public override void pause () {
			if (downloading) {
				download_operation.pause ();
				state = State.PAUSED;
			} else {
				base.pause ();
			}
		}

		public override void resume () {
			if (downloading) {
				state = State.DOWNLOADING;
				download_operation.resume ();
			} else {
				base.resume ();
			}
		}

		public override async void run_async () throws Error {
			FileInputStream? input = null;
			UnixOutputStream? output = null;

			try {
				if (download_operation != null) {
					yield download ();
					yield verify_checksum ();
				}

				yield unmount ();

				FileInfo info;
				input = yield get_input (out info);
				output = yield get_output ();
				total_bytes = (int64) info.get_size ();

				yield stream (input, output);
			} catch (Error e) {
				if (output != null) yield output.close_async (Priority.DEFAULT, null);
				if (input != null) yield input.close_async (Priority.DEFAULT, null);

				if (is_auth_dismissed (e))
					throw new IOError.CANCELLED (e.message);

				if (!(e is IOError.CANCELLED))
					failed (_("%s: %s").printf (state_label (state), e.message));

				throw e;
			}

			yield output.close_async (Priority.DEFAULT, null);
			yield input.close_async (Priority.DEFAULT, null);

			try {
				yield verify ();
			} catch (Error e) {
				if (!(e is IOError.CANCELLED) && !is_auth_dismissed (e))
					failed (_("%s: %s").printf (state_label (state), e.message));

				return;
			}

			completed ();
		}

		private async void unmount () throws Error {
			state = State.PREPARING;

			foreach (var obj in object_manager.get_objects ()) {
				var udisks_obj = obj as UDisks.Object;
				if (udisks_obj == null)
					continue;

				var blk = udisks_obj.block;
				if (blk == null || blk.drive != block.drive)
					continue;

				var filesystem = udisks_obj.filesystem;
				if (filesystem == null || filesystem.mount_points.length == 0)
					continue;

				yield filesystem.call_unmount (new Variant ("a{sv}", null), cancellable);
			}
		}

		private async void download () throws Error {
			state = State.DOWNLOADING;
			downloading = true;

			var skipped = false;

			var progress_id = download_operation.progress.connect (
				(written, total) => progress (written, total)
			);
			var failed_id = download_operation.failed.connect ((message) => failed (message));
			var completed_id = download_operation.completed.connect ((file) => image_file = file);
			var skipped_id = download_operation.skipped.connect ((file) => {
				image_file = file;
				skipped = true;
			});

			try {
				yield download_operation.run_async ();
			} finally {
				download_operation.disconnect (progress_id);
				download_operation.disconnect (failed_id);
				download_operation.disconnect (completed_id);
				download_operation.disconnect (skipped_id);
				downloading = false;
			}

			if (image_file == null)
				throw new IOError.FAILED (_("Download did not produce a file"));

			downloaded (image_file, skipped);
		}

		private async void verify_checksum () throws Error {
			if (os_image.checksum == null)
				return;

			state = State.CHECKSUM;

			var verified = yield os_image.verify_checksum (image_file, cancellable);
			if (!verified)
				throw new IOError.FAILED (_("Checksum mismatch - the download can be corrupted"));
		}

		private async FileInputStream get_input (out FileInfo file_info) throws Error {
			file_info = yield image_file.query_info_async (
				FileAttribute.STANDARD_SIZE,
				FileQueryInfoFlags.NONE,
				Priority.DEFAULT,
				cancellable
			);

			return yield image_file.read_async (Priority.DEFAULT, cancellable);
		}

		private async UnixOutputStream get_output () throws Error {
			UnixFDList fd_list;
			Variant out_fd;
			yield block.call_open_for_restore (
				new Variant ("a{sv}", null),
				null,
				cancellable,
				out out_fd,
				out fd_list
			);
			var fd = fd_list.get (out_fd.get_handle ());
			return new UnixOutputStream (fd, true);
		}

		private async void stream (FileInputStream input, UnixOutputStream output) throws Error {
			state = State.WRITING;

			var buf = new uint8[1024 * 1024];
			ssize_t n;

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
				source_checksum.update (buf[0:n], n);

				progress (bytes_written, total_bytes);
			}

			yield output.flush_async (Priority.DEFAULT, cancellable);
		}

		private async void verify () throws Error {
			state = State.VERIFYING;

			UnixFDList fd_list;
			Variant out_fd;
			yield block.call_open_for_backup (
				new Variant ("a{sv}", null),
				null,
				cancellable,
				out out_fd,
				out fd_list
			);

			var fd = fd_list.get (out_fd.get_handle ());
			var input = new UnixInputStream (fd, true);

			var device_checksum = new Checksum (ChecksumType.SHA256);
			var buf = new uint8[1024 * 1024];
			int64 bytes_verified = 0;
			Error? read_error = null;

			ssize_t n;
			while (bytes_verified < total_bytes) {
				var remaining = total_bytes - bytes_verified;
				var chunk_size = (size_t) int64.min (remaining, buf.length);

				try {
					n = yield input.read_async (buf[0:chunk_size], Priority.DEFAULT, cancellable);
				} catch (Error e) {
					read_error = e;
					break;
				}

				if (n == 0)
					break;

				device_checksum.update (buf[0:n], n);
				bytes_verified += n;
				progress (bytes_verified, total_bytes);
			}

			yield input.close_async (Priority.DEFAULT, cancellable);

			if (read_error != null)
				throw read_error;

			if (source_checksum.get_string () != device_checksum.get_string ())
				throw new IOError.FAILED (_("Verification failed: written data does not match source"));
		}

		private static bool is_auth_dismissed (Error e) {
			return e.message.contains ("NotAuthorizedDismissed");
		}
	}
}
