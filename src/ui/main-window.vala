/* main-window.vala
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

		[GtkChild] private unowned DownloadPage download_page;
		[GtkChild] private unowned HomePage home_page;

		static construct {
			typeof (HomePage).ensure ();
			typeof (DownloadPage).ensure ();
		}

		public MainWindow (
			Tailor.Application app,
			OsinfoService osinfo_service,
			UsbService usb_service
		) {
			Object (application: app);

			download_page.osinfo_service = osinfo_service;
			download_page.usb_service = usb_service;
			download_page.primary_os_title = app.settings.get_string ("primary-os-title");

			osinfo_service.loaded.connect (download_page.populate);
			osinfo_service.load_failed.connect (download_page.show_error);

			home_page.devices_page.usb_service = usb_service;
		}
	}
}
