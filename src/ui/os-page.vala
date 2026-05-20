/* os-page.vala
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

	[GtkTemplate (ui = "/org/altlinux/Tailor/os-page.ui")]
	public class OsPage : Adw.NavigationPage {

		[GtkChild] private unowned Adw.ComboRow devices_row;

		public UsbService usb_service { get; construct set; }
		private ListStore device_store = new ListStore (typeof (UsbDto));

		construct {
			notify["usb-service"].connect (on_usb_service_set);

			devices_row.model = new Gtk.SingleSelection (device_store);
			devices_row.expression = new Gtk.PropertyExpression (typeof (UsbDto), null, "name");
		}

		private void on_usb_service_set () {
			if (usb_service == null)
				return;

			usb_service.device_added.connect (add_device);
			usb_service.device_removed.connect (remove_device);
			usb_service.device_updated.connect (update_device);
		}

		public void add_device (UsbDto device) {
			device_store.append (device);
		}

		public void remove_device (string object_path) {
			for (uint i = 0; i < device_store.n_items; i++) {
				var device = (UsbDto) device_store.get_item (i);
				if (device.object_path == object_path) {
					device_store.remove (i);
					return;
				}
			}
		}

		public void update_device (UsbDto device) {
			for (uint i = 0; i < device_store.n_items; i++) {
				var current = (UsbDto) device_store.get_item (i);
				if (current.object_path == device.object_path) {
					current.name = device.name;
					return;
				}
			}
		}
	}
}
