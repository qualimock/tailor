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
			var device_info_set = Win32.get_class_devs (
				&Win32.guid_devinterface_disk,
				null,
				null,
				Win32.DeviceInfoFlags.PRESENT | Win32.DeviceInfoFlags.DEVICEINTERFACE
			);

			uint32 index = 0;
			uint32 found = 0;

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

				found++;
				index++;
			}

			Win32.destroy_device_info_list (device_info_set);

			stdout.printf ("[usb-provider-windows] found %u disk interface(s)\n", found);
		}

		public IDeviceHandle get_device_handle (UsbDevice device) throws Error {
			throw new IOError.NOT_SUPPORTED ("Windows device handle not implemented yet");
		}
	}
}
