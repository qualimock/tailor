/* mainwindow.vala
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

	[GtkTemplate (ui = "/org/altlinux/Tailor/main-window.ui")]
	public class MainWindow : Adw.ApplicationWindow {

		[GtkChild]
		private unowned Gtk.Box devices;

		public MainWindow (Adw.Application app) {
			Object (application: app);

			create_device_card ();
		}

		[GtkCallback]
		private void create_device_card () {
			var device_card = new DeviceCard ();
			device_card.device_name = "UASSBEE";
			device_card.size = 300;

			devices.append (device_card);
		}
	}
}
