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
		}

		public void add_device (UsbDto device) {
			device_store.append (device);
		}

		public void remove_device (string object_path) {
			var match = usb_service.devices.first_match (
				d => d.object_path == object_path
			);

			uint index;
			if (device_store.find (match, out index))
				device_store.remove (index);
		}
	}
}
