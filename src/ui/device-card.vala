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

		[GtkChild] private unowned Gtk.Label name_label;
		[GtkChild] private unowned Gtk.Image icon_image;
		[GtkChild] private unowned Gtk.Label description_label;
		[GtkChild] private unowned Gtk.Label size_label;
		[GtkChild] private unowned Gtk.Label address_label;
		[GtkChild] private unowned Gtk.Button details_button;
		[GtkChild] private unowned Gtk.Button restore_button;

		private Icon _icon;
		public Icon icon {
			get { return _icon; }
			set {
				_icon = value;
				icon_image.gicon = _icon;
			}
		}

		private string _device_name;
		public string device_name {
			get { return _device_name; }
			set {
				_device_name = value;
				name_label.label = _device_name;
			}
		}

		private string _size;
		public string size {
			get { return _size; }
			set {
				_size = value;
				size_label.label = _size;
			}
		}

		private string _address;
		public string address {
			get { return _address; }
			set {
				_address = value;
				address_label.label = _address;
			}
		}

		private string _description;
		public string description {
			get { return _description; }
			set {
				_description = value;
				description_label.label = _description;
			}
		}

		public DeviceCard () {
			Object ();
		}
	}
}
