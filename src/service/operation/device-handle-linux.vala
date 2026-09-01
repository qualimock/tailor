/* device-handle-linux.vala
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

	public class DeviceHandleLinux : Object, IDeviceHandle {

		private UDisks.Block block;
		private DBusObjectManager object_manager;

		public DeviceHandleLinux (UDisks.Block block, DBusObjectManager object_manager) {
			this.block = block;
			this.object_manager = object_manager;
		}

		public async void unmount (Cancellable cancellable) throws Error {
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

		public async Checksum write (
			InputStream source,
			int64 total_bytes,
			IPauseGate pause_gate,
			Cancellable cancellable
		) throws Error {
			var output = yield get_output (cancellable);

			try {
				var checksum = yield stream (
					source,
					output,
					total_bytes,
					pause_gate,
					cancellable
				);
				yield output.close_async (Priority.DEFAULT, cancellable);

				return checksum;
			} catch (Error e) {
				yield output.close_async (Priority.DEFAULT, null);

				throw e;
			}
		}

		public async void verify (
			Checksum expected,
			int64 total_bytes,
			Cancellable cancellable
		) throws Error {
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

			if (expected.get_string () != device_checksum.get_string ())
				throw new IOError.FAILED (_("Verification failed: written data does not match source"));
		}

		public async void format (
			string fstype,
			Cancellable cancellable
		) throws Error {
			yield unmount (cancellable);
			yield block.call_format (fstype, new Variant ("a{sv}", null), cancellable);
		}

		public bool is_auth_dismissed (Error e) {
			return e.message.contains ("NotAuthorizedDismissed");
		}

		private async UnixOutputStream get_output (Cancellable cancellable) throws Error {
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

		private async Checksum stream (
			InputStream input,
			UnixOutputStream output,
			int64 total_bytes,
			IPauseGate pause_gate,
			Cancellable cancellable
		) throws Error {
			int64 bytes_written = 0;
			var checksum = new Checksum (ChecksumType.SHA256);

			var buf = new uint8[1024 * 1024];
			ssize_t n;

			while ((n = yield input.read_async (buf, Priority.DEFAULT, cancellable)) > 0) {
				yield pause_gate.wait_for_resume ();

				size_t written;

				yield output.write_all_async (
					buf[0:n],
					Priority.DEFAULT,
					cancellable,
					out written
				);

				bytes_written += written;
				checksum.update (buf[0:n], n);

				progress (bytes_written, total_bytes);
			}

			yield output.flush_async (Priority.DEFAULT, cancellable);
			return checksum;
		}
	}
}
