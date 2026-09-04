/* device-handle-windows.vala
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

	public class DeviceHandleWindows : Object, IDeviceHandle {

		private string device_path;
		private Gee.ArrayList<void*> locked_volume_handles = new Gee.ArrayList<void*> ();
		private void* helper_pipe = null;

		public DeviceHandleWindows (string device_path) {
			this.device_path = device_path;
		}

		public async void unmount (Cancellable cancellable) throws Error {
			var maybe_device_number = get_device_number ();
			if (maybe_device_number == null) {
				warning ("unmount: could not resolve device number for %s", device_path);
				return;
			}

			uint32 device_number = maybe_device_number;

			var volume_path_buffer = new uint8[260];
			var find_handle = Win32.find_first_volume (volume_path_buffer, volume_path_buffer.length);

			if (find_handle == Win32.invalid_handle_value) {
				warning ("FindFirstVolume failed, GetLastError=%u", Win32.get_last_error ());
				return;
			}

			while (true) {
				var volume_path = (string) volume_path_buffer;

				if (volume_matches_device (volume_path, device_number))
					dismount_volume (volume_path);

				if (!Win32.find_next_volume (find_handle, volume_path_buffer, volume_path_buffer.length))
					break;
			}

			Win32.find_volume_close (find_handle);
		}

		private void dismount_volume (string volume_path) {
			var volume_handle = Win32.create_file (
				volume_path.substring (0, volume_path.length - 1),
				Win32.GENERIC_READ | Win32.GENERIC_WRITE,
				Win32.FILE_SHARE_READ | Win32.FILE_SHARE_WRITE,
				null,
				Win32.OPEN_EXISTING,
				0,
				null
			);

			if (volume_handle == Win32.invalid_handle_value) {
				warning ("open for dismount failed for %s, GetLastError=%u", volume_path, Win32.get_last_error ());
				return;
			}

			uint32 bytes_returned;

			var locked = Win32.device_io_control (
				volume_handle, Win32.FSCTL_LOCK_VOLUME, null, 0, null, 0, out bytes_returned, null
			);

			if (!locked)
				warning ("FSCTL_LOCK_VOLUME failed for %s, GetLastError=%u", volume_path, Win32.get_last_error ());

			var dismounted = Win32.device_io_control (
				volume_handle, Win32.FSCTL_DISMOUNT_VOLUME, null, 0, null, 0, out bytes_returned, null
			);

			if (!dismounted)
				warning ("FSCTL_DISMOUNT_VOLUME failed for %s, GetLastError=%u", volume_path, Win32.get_last_error ());

			locked_volume_handles.add (volume_handle);
		}

		private void release_locked_volumes () {
			foreach (var volume_handle in locked_volume_handles)
				Win32.close_handle (volume_handle);

			locked_volume_handles.clear ();
		}

		private delegate void BlockingAction () throws Error;

		private async void run_blocking (owned BlockingAction action) throws Error {
			SourceFunc callback = run_blocking.callback;
			Error? thread_error = null;

			new Thread<void>.try ("device-handle-windows-io", () => {
				try {
					action ();
				} catch (Error e) {
					thread_error = e;
				}
				Idle.add ((owned) callback);
			});

			yield;

			if (thread_error != null)
				throw thread_error;
		}

		public async Checksum write (
			InputStream source,
			int64 total_bytes,
			IPauseGate pause_gate,
			Cancellable cancellable
		) throws Error {
			try {
				yield run_blocking (() => start_helper_and_lock ());

				var checksum = new Checksum (ChecksumType.SHA256);
				var buf = new uint8[1024 * 1024];
				int64 bytes_written = 0;
				ssize_t n;

				while ((n = yield source.read_async (buf, Priority.DEFAULT, cancellable)) > 0) {
					yield pause_gate.wait_for_resume ();

					var chunk = buf[0:n];
					yield run_blocking (() => send_write_chunk (chunk));

					bytes_written += n;
					checksum.update (chunk, n);
					progress (bytes_written, total_bytes);
				}

				return checksum;
			} catch (Error e) {
				close_helper ();
				throw e;
			}
		}

		private void send_write_chunk (uint8[] chunk) throws Error {
			try {
				FlashPipe.write_frame (helper_pipe, FlashPipe.TAG_WRITE, chunk);

				uint8 tag;
				uint8[] payload;
				FlashPipe.read_frame (helper_pipe, out tag, out payload);

				if (tag != FlashPipe.TAG_OK)
					throw new IOError.FAILED ("helper WRITE failed: %s".printf (FlashPipe.payload_to_string (payload)));
			} catch (FlashPipe.PipeError e) {
				throw new IOError.FAILED ("pipe communication failed: %s".printf (e.message));
			}
		}

		public async void verify (
			Checksum expected,
			int64 total_bytes,
			IPauseGate pause_gate,
			Cancellable cancellable
		) throws Error {
			if (helper_pipe == null)
				throw new IOError.FAILED ("verify() called without an active helper session");

			var device_checksum = new Checksum (ChecksumType.SHA256);
			int64 bytes_verified = 0;

			try {
				var total_bytes_payload = new uint8[8];
				for (int i = 0; i < 8; i++)
					total_bytes_payload[i] = (uint8) ((total_bytes >> (i * 8)) & 0xFF);

				yield run_blocking (() => FlashPipe.write_frame (helper_pipe, FlashPipe.TAG_VERIFY, total_bytes_payload));

				while (bytes_verified < total_bytes) {
					if (cancellable.is_cancelled ())
						throw new IOError.CANCELLED ("verify cancelled");

					yield pause_gate.wait_for_resume ();

					uint8 tag = 0;
					uint8[] payload = null;
					yield run_blocking (() => FlashPipe.read_frame (helper_pipe, out tag, out payload));

					if (tag == FlashPipe.TAG_ERROR)
						throw new IOError.FAILED ("helper VERIFY failed: %s".printf (FlashPipe.payload_to_string (payload)));

					if (tag != FlashPipe.TAG_DATA)
						throw new IOError.FAILED ("unexpected tag during VERIFY: %02x".printf (tag));

					device_checksum.update (payload, payload.length);
					bytes_verified += payload.length;
					progress (bytes_verified, total_bytes);
				}

				uint8 final_tag = 0;
				uint8[] final_payload = null;
				yield run_blocking (() => FlashPipe.read_frame (helper_pipe, out final_tag, out final_payload));

				if (final_tag != FlashPipe.TAG_OK) {
					throw new IOError.FAILED (
						"helper VERIFY failed: %s".printf (FlashPipe.payload_to_string (final_payload))
					);
				}
			} catch (FlashPipe.PipeError e) {
				throw new IOError.FAILED ("pipe communication failed: %s".printf (e.message));
			} finally {
				close_helper ();
			}

			if (device_checksum.get_string () != expected.get_string ())
				throw new IOError.FAILED (_("Verification failed: written data does not match source"));
		}

		public async void format (
			string fstype,
			Cancellable cancellable
		) throws Error {
			try {
				yield run_blocking (() => start_helper_and_lock ());
				release_locked_volumes ();

				uint8 tag = 0;
				uint8[] payload = null;

				yield run_blocking (() => {
					FlashPipe.write_frame (helper_pipe, FlashPipe.TAG_FORMAT, fstype.data);
					FlashPipe.read_frame (helper_pipe, out tag, out payload);
				});

				if (tag != FlashPipe.TAG_OK)
					throw new IOError.FAILED ("helper FORMAT failed: %s".printf (FlashPipe.payload_to_string (payload)));
			} catch (FlashPipe.PipeError e) {
				throw new IOError.FAILED ("pipe communication failed: %s".printf (e.message));
			} finally {
				close_helper ();
			}
		}

		public bool is_auth_dismissed (Error e) {
			return false;
		}

		private void start_helper_and_lock () throws Error {
			var pipe_name = "\\\\.\\pipe\\tailor-flash-%u".printf (Random.next_int ());

			var pipe_handle = Win32.create_named_pipe (
				pipe_name,
				Win32.PIPE_ACCESS_DUPLEX,
				Win32.PIPE_TYPE_BYTE | Win32.PIPE_WAIT,
				1, 4096, 4096, 0, null
			);

			if (pipe_handle == Win32.invalid_handle_value) {
				throw new IOError.FAILED (
					"CreateNamedPipe failed, GetLastError=%u".printf (Win32.get_last_error ())
				);
			}

			var helper_path = find_helper_exe ();

			var exec_info = Win32.ShellExecuteInfo ();
			exec_info.cb_size = (uint32) sizeof (Win32.ShellExecuteInfo);
			exec_info.mask = Win32.SEE_MASK_NOCLOSEPROCESS;
			exec_info.verb = "runas";
			exec_info.file = helper_path;
			exec_info.parameters = pipe_name;
			exec_info.show = Win32.SW_HIDE;

			if (!Win32.shell_execute_ex (&exec_info)) {
				var error_code = Win32.get_last_error ();
				Win32.close_handle (pipe_handle);

				if (error_code == Win32.ERROR_CANCELLED)
					throw new IOError.CANCELLED ("UAC prompt dismissed");

				throw new IOError.FAILED ("ShellExecuteEx failed, GetLastError=%u".printf (error_code));
			}

			if (!Win32.connect_named_pipe (pipe_handle, null)
				&& Win32.get_last_error () != Win32.ERROR_PIPE_CONNECTED) {
				Win32.close_handle (pipe_handle);
				throw new IOError.FAILED (
					"ConnectNamedPipe failed, GetLastError=%u".printf (Win32.get_last_error ())
				);
			}

			helper_pipe = pipe_handle;

			try {
				FlashPipe.write_frame (pipe_handle, FlashPipe.TAG_LOCK, device_path.data);

				uint8 tag;
				uint8[] payload;
				FlashPipe.read_frame (pipe_handle, out tag, out payload);

				if (tag != FlashPipe.TAG_OK)
					throw new IOError.FAILED ("helper LOCK failed: %s".printf (FlashPipe.payload_to_string (payload)));
			} catch (FlashPipe.PipeError e) {
				throw new IOError.FAILED ("pipe communication failed: %s".printf (e.message));
			}
		}

		private void close_helper () {
			release_locked_volumes ();

			if (helper_pipe == null)
				return;

			try {
				FlashPipe.write_frame (helper_pipe, FlashPipe.TAG_CLOSE, new uint8[0]);
			} catch (FlashPipe.PipeError e) {
				warning ("close_helper: write CLOSE failed: %s", e.message);
			}

			Win32.close_handle (helper_pipe);
			helper_pipe = null;
		}

		private string find_helper_exe () {
			var buffer = new uint8[260];
			Win32.get_module_file_name (null, buffer, buffer.length);

			var own_path = (string) buffer;

			var last_slash = own_path.last_index_of ("\\");
			var dir = last_slash >= 0 ? own_path.substring (0, last_slash + 1) : "";

			return dir + "FlashHelper.exe";
		}

		private uint32? get_device_number () {
			var disk_handle = Win32.create_file (
				device_path,
				0,
				Win32.FILE_SHARE_READ | Win32.FILE_SHARE_WRITE,
				null,
				Win32.OPEN_EXISTING,
				0,
				null
			);

			if (disk_handle == Win32.invalid_handle_value) {
				warning ("CreateFile(%s) failed, GetLastError=%u", device_path, Win32.get_last_error ());
				return null;
			}

			Win32.StorageDeviceNumber device_number = {};
			uint32 bytes_returned;

			var ok = Win32.device_io_control (
				disk_handle,
				Win32.IOCTL_STORAGE_GET_DEVICE_NUMBER,
				null,
				0,
				&device_number,
				(uint32) sizeof (Win32.StorageDeviceNumber),
				out bytes_returned,
				null
			);

			Win32.close_handle (disk_handle);

			if (!ok)
				return null;

			return device_number.device_number;
		}

		private bool volume_matches_device (string volume_path, uint32 device_number) {
			var volume_handle = Win32.create_file (
				volume_path.substring (0, volume_path.length - 1),
				0,
				Win32.FILE_SHARE_READ | Win32.FILE_SHARE_WRITE,
				null,
				Win32.OPEN_EXISTING,
				0,
				null
			);

			if (volume_handle == Win32.invalid_handle_value)
				return false;

			Win32.StorageDeviceNumber volume_device_number = {};
			uint32 bytes_returned;

			var ok = Win32.device_io_control (
				volume_handle,
				Win32.IOCTL_STORAGE_GET_DEVICE_NUMBER,
				null,
				0,
				&volume_device_number,
				(uint32) sizeof (Win32.StorageDeviceNumber),
				out bytes_returned,
				null
			);

			Win32.close_handle (volume_handle);

			if (!ok)
				return false;

			return volume_device_number.device_number == device_number;
		}
	}
}
