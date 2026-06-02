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

		private async void open_in_disks () {
			try {
				if (FileUtils.test ("/.flatpak-info", FileTest.EXISTS)) {
					yield open_in_disks_from_flatpak ();
				} else {
					yield open_in_disks_native ();
				}
			} catch (Error e) {
				warning ("Failed to open gnome-disks: %s", e.message);
			}
		}

		private async void open_in_disks_native () throws Error {
			try {
				new Subprocess.newv ({
						"gnome-disks", "--block-device", address
					},
					SubprocessFlags.NONE
				);
			} catch (Error e) {
				new Subprocess.newv ({
						"flatpak", "run",
						"org.gnome.DiskUtility", "--block-device", address
					},
					SubprocessFlags.NONE
				);
			}
		}

		private async void open_in_disks_from_flatpak () throws Error {
			var probe = new Subprocess.newv ({
					"flatpak-spawn", "--host",
					"sh", "-c", "command -v gnome-disks"
				},
				SubprocessFlags.NONE
			);
			yield probe.wait_async (null);

			string[] cmd;
			if (probe.get_exit_status () == 0) {
				cmd = {
					"flatpak-spawn", "--host",
					"gnome-disks", "--block-device", address
				};
			} else {
				cmd = {
					"flatpak-spawn", "--host",
					"flatpak", "run", "org.gnome.DiskUtility", "--block-device", address
				};
			}
			new Subprocess.newv (cmd, SubprocessFlags.NONE);
		}

		[GtkCallback]
		private void on_more_in_disks_clicked () {
			open_in_disks.begin ();
		}
	}
}
