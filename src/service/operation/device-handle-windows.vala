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

		public async Checksum write (
			InputStream source,
			int64 total_bytes,
			IPauseGate pause_gate,
			Cancellable cancellable
		) throws Error {
			throw new IOError.NOT_SUPPORTED ("Windows flash helper not implemented yet");
		}

		public async void verify (
			Checksum expected,
			int64 total_bytes,
			IPauseGate pause_gate,
			Cancellable cancellable
		) throws Error {
			throw new IOError.NOT_SUPPORTED ("Windows flash helper not implemented yet");
		}

		public async void format (
			string fstype,
			Cancellable cancellable
		) throws Error {
			throw new IOError.NOT_SUPPORTED ("Windows flash helper not implemented yet");
		}

		public bool is_auth_dismissed (Error e) {
			return false;
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
