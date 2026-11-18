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

		[GtkChild] private unowned Adw.ToastOverlay toast_overlay;
		[GtkChild] private unowned Adw.NavigationView navigation_view;
		[GtkChild] private unowned DownloadPage download_page;

		public ServiceContext service { get; construct; }

		static construct {
			typeof (HomePage).ensure ();
			typeof (DownloadPage).ensure ();
			typeof (OsPage).ensure ();
			typeof (ImagePage).ensure ();
			typeof (FlashPage).ensure ();
			typeof (StatusPageWithBadge).ensure ();
		}

		construct {
			if (Tailor.PROFILE == "development")
				add_css_class ("devel");

			service.osinfo.loaded.connect (download_page.populate);
			service.osinfo.load_failed.connect (download_page.show_error);
			service.ui.toast_requested.connect (toast => toast_overlay.add_toast (toast));
		}

		public MainWindow (Tailor.Application app, ServiceContext service) {
			Object (application: app, service: service);

			download_page.primary_os_title = service.ui.get_primary_os_title (
				app.settings.get_string ("primary-os"),
				app.settings.get_string ("primary-os-title-fallback")
			);
		}

		public void open_image_file (File file) {
			service.image_file = file;

			service.osinfo.detect_os.begin (file.get_path (), (obj, res) => {
				var family = service.osinfo.detect_os.end (res);

				if (family == null) {
					navigation_view.push ((ImagePage) navigation_view.find_page ("image-page"));
					return;
				}

				var page = (OsPage) navigation_view.find_page ("os-page");
				page.configure (family, null, file);
				navigation_view.push (page);
			});
		}
	}
}
