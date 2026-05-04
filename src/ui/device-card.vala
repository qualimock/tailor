/* device-card.vala
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

	[GtkTemplate (ui = "/org/altlinux/Tailor/device-card.ui")]
	public class DeviceCard : Gtk.Box {

		[GtkChild]
		private unowned Gtk.Image icon;
		[GtkChild]
		private unowned Gtk.Label name_label;
		[GtkChild]
		private unowned Gtk.Label size_label;
		[GtkChild]
		private unowned Gtk.Label address_label;
		[GtkChild]
		private unowned Gtk.Label type_label;
		[GtkChild]
		private unowned Gtk.Button details_button;
		[GtkChild]
		private unowned Gtk.Button restore_button;

		private string _name;
		public string device_name {
			get { return _name; }
			set {
				_name = value;
				name_label.label = value;
				icon.set_from_icon_name ("usb-stick-symbolic");
			}
		}

		private string calculate_size (uint size) {
			return size.to_string ();
		}

		private uint _size;
		public uint size {
			get { return _size; }
			set {
				_size = value;
				size_label.label = calculate_size (value);
			}
		}

		public DeviceCard () {
			Object ();
		}
	}
}
