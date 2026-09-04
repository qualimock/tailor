/* usb-provider-windows.vala
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

	public class UsbProviderWindows : Object, IUsbProvider {

		public async void init_async () throws Error {
			var known_devices = scan_devices ();
			foreach (var device in known_devices.values)
				device_added (device);
		}

		public IDeviceHandle get_device_handle (UsbDevice device) throws Error {
			return new DeviceHandleWindows (device.object_path);
		}

		private Gee.HashMap<string, UsbDevice> scan_devices () {
			var result = new Gee.HashMap<string, UsbDevice> ();

			var device_info_set = Win32.get_class_devs (
				&Win32.guid_devinterface_disk,
				null,
				null,
				Win32.DeviceInfoFlags.PRESENT | Win32.DeviceInfoFlags.DEVICEINTERFACE
			);

			uint32 index = 0;

			while (true) {
				var iface_data = Win32.DeviceInterfaceData ();
				iface_data.cb_size = (uint32) sizeof (Win32.DeviceInterfaceData);

				var has_more = Win32.enum_device_interfaces (
					device_info_set,
					null,
					&Win32.guid_devinterface_disk,
					index,
					ref iface_data
				);

				if (!has_more)
					break;

				var device = build_device (device_info_set, ref iface_data);
				if (device != null)
					result[device.object_path] = device;

				index++;
			}

			Win32.destroy_device_info_list (device_info_set);

			return result;
		}

		private UsbDevice? build_device (void* device_info_set, ref Win32.DeviceInterfaceData iface_data) {
			var device_path = get_device_path (device_info_set, ref iface_data);
			if (device_path == null) {
				warning ("failed to resolve device interface detail");
				return null;
			}

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
				warning ("CreateFile failed for %s, GetLastError=%u", device_path, Win32.get_last_error ());
				return null;
			}

			var device = read_device (disk_handle);
			Win32.close_handle (disk_handle);

			return device;
		}

		private string? get_device_path (void* device_info_set, ref Win32.DeviceInterfaceData iface_data) {
			uint32 required_size;

			Win32.get_device_interface_detail (
				device_info_set,
				&iface_data,
				null,
				0,
				out required_size,
				null
			);

			if (required_size == 0)
				return null;

			var detail_buffer = new uint8[required_size];
			((Win32.DeviceInterfaceDetailData*) detail_buffer)->cb_size =
				(uint32) sizeof (Win32.DeviceInterfaceDetailData);

			var ok = Win32.get_device_interface_detail (
				device_info_set,
				&iface_data,
				detail_buffer,
				required_size,
				null,
				null
			);

			if (!ok)
				return null;

			// DevicePath (UTF-16) starts right after the leading cbSize DWORD
			void* wide_path = (void*) ((uint8*) detail_buffer + sizeof (uint32));
			return utf16_to_utf8 (wide_path);
		}

		private UsbDevice? read_device (void* disk_handle) {
			Win32.StorageDeviceNumber device_number = {};
			uint32 bytes_returned;

			var got_number = Win32.device_io_control (
				disk_handle,
				Win32.IOCTL_STORAGE_GET_DEVICE_NUMBER,
				null,
				0,
				&device_number,
				(uint32) sizeof (Win32.StorageDeviceNumber),
				out bytes_returned,
				null
			);

			if (!got_number) {
				warning ("IOCTL_STORAGE_GET_DEVICE_NUMBER failed, GetLastError=%u", Win32.get_last_error ());
				return null;
			}

			var descriptor_buffer = query_device_descriptor_buffer (disk_handle);
			if (descriptor_buffer == null) {
				warning ("IOCTL_STORAGE_QUERY_PROPERTY failed for device_number=%u", device_number.device_number);
				return null;
			}

			Win32.StorageDeviceDescriptor* descriptor = (Win32.StorageDeviceDescriptor*) descriptor_buffer;

			if (descriptor->bus_type != Win32.StorageBusType.USB)
				return null;

			var object_path = "\\\\.\\PhysicalDrive%u".printf (device_number.device_number);

			string filesystem;
			bool has_image;
			resolve_filesystem (device_number.device_number, out filesystem, out has_image);

			var device = new UsbDevice (object_path);
			device.device_file = object_path;
			device.name = build_display_name (descriptor);
			device.size = get_disk_size (disk_handle);
			device.size_display = format_size (device.size);
			device.filesystem = filesystem;
			device.has_image = has_image;

			return device;
		}

		private void resolve_filesystem (uint32 device_number, out string filesystem, out bool has_image) {
			filesystem = "";
			has_image = false;

			var volume_path_buffer = new uint8[260];
			var find_handle = Win32.find_first_volume (volume_path_buffer, volume_path_buffer.length);

			if (find_handle == Win32.invalid_handle_value) {
				warning ("FindFirstVolume failed, GetLastError=%u", Win32.get_last_error ());
				return;
			}

			while (true) {
				var volume_path = (string) volume_path_buffer;

				if (volume_matches_device (volume_path, device_number)) {
					filesystem = query_filesystem_name (volume_path);
					has_image = filesystem == "CDFS" || filesystem == "UDF";
					break;
				}

				if (!Win32.find_next_volume (find_handle, volume_path_buffer, volume_path_buffer.length))
					break;
			}

			Win32.find_volume_close (find_handle);
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

		private string query_filesystem_name (string volume_path) {
			var fs_name_buffer = new uint8[64];
			uint32 serial_number, max_component_length, file_system_flags;

			var ok = Win32.get_volume_information (
				volume_path,
				null,
				0,
				out serial_number,
				out max_component_length,
				out file_system_flags,
				fs_name_buffer,
				fs_name_buffer.length
			);

			if (!ok) {
				warning ("GetVolumeInformation failed for %s, GetLastError=%u", volume_path, Win32.get_last_error ());
				return "";
			}

			return (string) fs_name_buffer;
		}

		private string build_display_name (Win32.StorageDeviceDescriptor* descriptor) {
			var vendor = read_offset_string ((uint8*) descriptor, descriptor->vendor_id_offset);
			var product = read_offset_string ((uint8*) descriptor, descriptor->product_id_offset);

			if (vendor == "" && product == "")
				return _("USB drive");

			return "%s %s".printf (vendor, product).strip ();
		}

		private uint8[]? query_device_descriptor_buffer (void* disk_handle) {
			var query = Win32.StoragePropertyQuery ();
			query.property_id = Win32.StoragePropertyId.DEVICE_PROPERTY;
			query.query_type = Win32.StorageQueryType.STANDARD_QUERY;

			var buffer = new uint8[512];
			uint32 bytes_returned;

			var ok = Win32.device_io_control (
				disk_handle,
				Win32.IOCTL_STORAGE_QUERY_PROPERTY,
				&query,
				(uint32) sizeof (Win32.StoragePropertyQuery),
				buffer,
				buffer.length,
				out bytes_returned,
				null
			);

			if (!ok)
				return null;

			return buffer;
		}

		private string read_offset_string (uint8* descriptor_base, uint32 offset) {
			if (offset == 0)
				return "";

			return ((string) (descriptor_base + offset)).strip ();
		}

		private uint64 get_disk_size (void* disk_handle) {
			Win32.DiskGeometryEx geometry = {};
			uint32 bytes_returned;

			var ok = Win32.device_io_control (
				disk_handle,
				Win32.IOCTL_DISK_GET_DRIVE_GEOMETRY_EX,
				null,
				0,
				&geometry,
				(uint32) sizeof (Win32.DiskGeometryEx),
				out bytes_returned,
				null
			);

			return ok ? (uint64) geometry.disk_size : 0;
		}

		private string utf16_to_utf8 (void* wide_str) {
			var utf8_len = Win32.wide_char_to_multi_byte (
				Win32.CP_UTF8, 0, wide_str, -1, null, 0, null, null
			);

			if (utf8_len <= 0)
				return "";

			var utf8_buf = new uint8[utf8_len];

			Win32.wide_char_to_multi_byte (
				Win32.CP_UTF8, 0, wide_str, -1, utf8_buf, utf8_len, null, null
			);

			return (string) utf8_buf;
		}
	}
}
