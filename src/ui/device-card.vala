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
		[GtkChild] private unowned Gtk.Label filesystem_label;
		[GtkChild] private unowned Gtk.Label size_label;
		[GtkChild] private unowned Gtk.Label address_label;

		private string _device_name;
		public string device_name {
			get { return _device_name; }
			set {
				_device_name = value;
				name_label.label = value;
			}
		}

		private string _size;
		public string size {
			get { return _size; }
			set {
				_size = value;
				size_label.label = value;
			}
		}

		private string _address;
		public string address {
			get { return _address; }
			set {
				_address = value;
				address_label.label = value;
			}
		}

		private string _filesystem;
		public string filesystem {
			get { return _filesystem; }
			set {
				_filesystem = value;
				filesystem_label.label = value;
			}
		}

		[GtkCallback]
		private void on_more_in_disks_clicked () {
			try {
				var app = AppInfo.create_from_commandline (
					"gnome-disks --block-device " + _address,
					null,
					AppInfoCreateFlags.NONE
				);
				app.launch (null, null);
			} catch (Error e) {
				warning ("Failed to open gnome-disks: %s", e.message);
			}
		}

	}
}
