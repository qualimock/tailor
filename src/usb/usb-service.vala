/* usb-service.vala
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

	public class UsbService {

		private UsbProvider provider;

		public Gee.ArrayList<UsbDevice> devices { get; private set; }

		public signal void initialized ();
		public signal void init_failed (Error e);

		public signal void device_added (UsbDevice device);
		public signal void device_removed (string object_path);
		public signal void device_updated (UsbDevice device);

		public UsbService () {
			devices = new Gee.ArrayList<UsbDevice> ();
		}

		public async void init_async () {
			provider = new UsbProvider ();

			provider.device_added.connect (on_device_added);
			provider.device_removed.connect (on_device_removed);
			provider.device_updated.connect (on_device_updated);

			try {
				yield provider.init_async ();
			} catch (Error e) {
				init_failed (e);
				return;
			}

			initialized ();
		}

		private void on_device_added (UsbDevice device) {
			devices.add (device);
			device_added (device);
		}

		private void on_device_removed (string object_path) {
			device_removed (object_path);

			var removed = devices.first_match (d => d.object_path == object_path);
			if (removed == null)
				return;

			devices.remove (removed);
		}

		private void on_device_updated (UsbDevice device) {
			var old = devices.first_match (d => d.object_path == device.object_path);
			if (old == null)
				return;

			old.device_file = device.device_file;
			old.name = device.name;
			old.size = device.size;
			old.size_display = device.size_display;
			old.filesystem = device.filesystem;

			device_updated (old);
		}
	}
}
