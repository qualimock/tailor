/* devices-page.vala
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

	[GtkTemplate (ui = "/org/altlinux/Tailor/devices-page.ui")]
	public class DevicesPage : Adw.Bin {

		[GtkChild] private unowned Gtk.Box devices_box;

		private ServiceContext _service;
		public ServiceContext service {
			get { return _service; }
			set {
				_service = value;
				if (value == null)
					return;

				value.usb.device_added.connect (add_device);
				value.usb.device_removed.connect (remove_device);
				value.usb.device_updated.connect (update_device);
			}
		}

		private Gee.HashMap<string, DeviceCard> cards = new Gee.HashMap<string, DeviceCard> ();

		public void add_device (UsbDevice device) {
			var card = new DeviceCard ();
			card.device_name = device.name;
			card.filesystem = device.filesystem;
			card.size = device.size_display;
			card.address = device.device_file;

			cards[device.object_path] = card;
			devices_box.append (card);
			devices_box.visible = true;
		}

		public void remove_device (string object_path) {
			var card = cards[object_path];
			if (card == null)
				return;

			cards.unset (object_path);
			devices_box.remove (card);
			if (cards.is_empty)
				devices_box.visible = false;
		}

		public void update_device (UsbDevice device) {
			var card = cards[device.object_path];
			if (card == null)
				return;

			card.filesystem = device.filesystem;
			card.size = device.size_display;
		}
	}
}
