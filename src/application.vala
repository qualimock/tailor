/* app.vala
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

	public class Application : Adw.Application {

		private const ActionEntry[] APP_ENTRIES = {
			{ "open-app-page", open_app_page },
			{ "about", about_activated },
			{ "quit", quit }
		};

		private MainWindow main_window;

		public Application () {
			Object (application_id: Tailor.ID,
			        resource_base_path: "/org/altlinux/Tailor");
		}

		public override void startup () {
			base.startup ();

			add_action_entries (APP_ENTRIES, this);
			set_accels_for_action ("app.quit", { "<Ctrl>Q" });
		}

		public override void activate () {
			Gtk.IconTheme.get_for_display (Gdk.Display.get_default ())
				.add_resource_path ("/org/altlinux/Tailor/icons");

			if (main_window != null) {
				main_window.present ();
				return;
			}

			main_window = new MainWindow (this);

			main_window.present ();
		}

		private void open_app_page () {
			var launcher = new Gtk.UriLauncher ("appstream://org.altlinux.Tailor");

			launcher.launch.begin (null, null, (obj, res) => {
				try {
					launcher.launch.end (res);
				} catch (Error e) {
					warning ("Failed to open app page: %s", e.message);
				}
			});
		}

		private void about_activated () {
			if (main_window == null) return;

			var dialog = new Adw.AboutDialog.from_appdata ("org/altlinux/Tailor/org.altlinux.Tailor.metainfo.xml", VERSION) {
				copyright = "© 2026 ALT Linux Team",
				developers = {
					"Alexey \"qualimock\" Volkov <qualimock@altlinux.org>",
				},
				artists = { "Viktoria \"gingercat\" Zubacheva" },
				translator_credits = _("translator-credits")
			};

			dialog.present (main_window);
		}
	}
}
