/* usb-device.vala
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

	public class UsbDevice : Object {

		public string object_path { get; construct; }
		public string device_file { get; set; }
		public string name { get; set; }
		public string filesystem { get; set; }
		public uint64 size { get; set; }
		public string size_display { get; set; }
		public bool has_image { get; set; }

		public UsbDevice (string object_path) {
			Object (object_path: object_path);
		}
	}
}
