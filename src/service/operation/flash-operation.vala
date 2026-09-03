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

		private OsImage? os_image = null;
		private File? image_file = null;
		private DownloadOperation? download_operation = null;
		private Cancellable? verify_cancellable;
		private bool downloading = false;
		private bool verify_skipped = false;
		IDeviceHandle device_handle;

		public signal void completed ();
		public signal void downloaded (File file, bool skipped);

		public FlashOperation.with_file (
			IDeviceHandle device_handle,
			File image_file,
			Cancellable cancellable
		) {
			this.device_handle = device_handle;
			this.image_file = image_file;
			this.cancellable = cancellable;
		}

		public FlashOperation.with_download (
			IDeviceHandle device_handle,
			OsImage os_image,
			Cancellable cancellable
		) {
			this.device_handle = device_handle;
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
			int64 total_bytes = 0;
			Checksum? checksum = null;

			var progress_id = device_handle.progress.connect (
				(written, total) => progress (written, total)
			);

			try {
				if (download_operation != null) {
					yield download ();
					yield verify_checksum ();
				}

				var file_info = yield image_file.query_info_async (
					FileAttribute.STANDARD_SIZE,
					FileQueryInfoFlags.NONE,
					Priority.DEFAULT,
					cancellable
				);
				total_bytes = (int64) file_info.get_size ();

				state = State.PREPARING;
				yield device_handle.unmount (cancellable);
				input = yield image_file.read_async (Priority.DEFAULT, cancellable);

				state = State.WRITING;
				checksum = yield device_handle.write (
					input,
					total_bytes,
					this,
					cancellable
				);
			} catch (Error e) {
				if (input != null)
					yield input.close_async (Priority.DEFAULT, null);

				if (device_handle.is_auth_dismissed (e))
					throw new IOError.CANCELLED (e.message);

				if (!(e is IOError.CANCELLED))
					failed (_("%s: %s").printf (state_label (state), e.message));

				throw e;
			}

			yield input.close_async (Priority.DEFAULT, null);

			verify_cancellable = new Cancellable ();
			var verify_link_id = cancellable.connect (() => verify_cancellable.cancel ());

			state = State.VERIFYING;
			try {
				yield device_handle.verify (checksum, total_bytes, this, verify_cancellable);
			} catch (Error e) {
				if (verify_skipped) {
					completed ();
					return;
				}

				if (!(e is IOError.CANCELLED) && !device_handle.is_auth_dismissed (e))
					failed (_("%s: %s").printf (state_label (state), e.message));

				return;
			} finally {
				cancellable.disconnect (verify_link_id);
				device_handle.disconnect (progress_id);
			}

			completed ();
		}

		public void skip_verification () {
			verify_skipped = true;
			verify_cancellable?.cancel ();
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
	}
}
