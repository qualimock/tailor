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

		[GtkChild] private unowned Gtk.DropDown edition_dropdown;
		[GtkChild] private unowned Gtk.DropDown version_dropdown;
		[GtkChild] private unowned Gtk.DropDown arch_dropdown;
		[GtkChild] private unowned Gtk.DropDown devices_dropdown;

		private ServiceContext _service;
		public ServiceContext service {
			get { return _service; }
			set {
				_service = value;
				if (value == null)
					return;

				value.usb.device_added.connect (add_device);
				value.usb.device_removed.connect (remove_device);
			}
		}

		private ListStore device_store = new ListStore (typeof (UsbDto));

		construct {
			devices_dropdown.model = new Gtk.SingleSelection (device_store);
			devices_dropdown.expression = new Gtk.PropertyExpression (typeof (UsbDto), null, "name");
		}

		public void add_device (UsbDto device) {
			device_store.append (device);
		}

		public void remove_device (string object_path) {
			var match = service.usb.devices.first_match (
				d => d.object_path == object_path
			);

			uint index;
			if (device_store.find (match, out index))
				device_store.remove (index);
		}
	}
}
