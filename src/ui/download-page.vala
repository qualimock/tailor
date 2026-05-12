/* download-page.vala
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

	[GtkTemplate (ui = "/org/altlinux/Tailor/download-page.ui")]
	public class DownloadPage : Adw.NavigationPage {

		[GtkChild] private unowned Adw.StatusPage spinner;
		[GtkChild] private unowned Adw.StatusPage download_error;

		[GtkChild] private unowned Gtk.Entry search_entry;

		[GtkChild] private unowned Gtk.Label primary_os_label;
		[GtkChild] private unowned Gtk.ListBox primary_os_list;

		[GtkChild] private unowned Gtk.ListBox other_os_list;

		[GtkChild] private unowned Gtk.DropDown arch_dropdown;

		private Gee.ArrayList<Osinfo.Os> os_list;
		private string primary_distro;
		private Gee.HashMap<string, OsFilter> filters;

		construct {
			var application = (Tailor.Application) GLib.Application.get_default ();

			primary_distro = application.settings.get_string ("primary-os");
			primary_os_label.label = application.settings.get_string ("primary-os-title");
			filters = new Gee.HashMap<string, OsFilter> ();

			var future = Dex.thread_spawn ("osinfo-loader", () => {
				try {
					var db = OsinfoLoader.load_db ();
					os_list = OsinfoLoader.get_os_list (db);
					return new Dex.Future.for_boolean (true);
				} catch (Error e) {
					return new Dex.Future.for_error (e);
				}
			});

			var chain = new Dex.Future.then (future, (f) => {
				message ("OS database loaded");

				spinner.visible = false;
				populate_os_list ();

				var filter_name = "Architecture";
				filters[filter_name] = new OsFilter ();
				populate_dropdown (
					arch_dropdown,
					OsinfoLoader.get_arch_list (os_list),
					_(filter_name)
				);

				filter_name = "Distribution";
				filters[filter_name] = new OsFilter ();
				populate_dropdown (
					distro_dropdown,
					OsinfoLoader.get_distro_list (os_list),
					_(filter_name)
				);

				return new Dex.Future.for_boolean (true);
			});

			chain = new Dex.Future.catch (chain, (f) => {
				try {
					f.get_value ();
				} catch (Error e) {
					warning ("Failed to load OS database: %s", e.message);
				}

				spinner.visible = false;
				download_error.visible = true;
				return new Dex.Future.for_boolean (false);
			});

			chain.disown ();
		}

		[GtkCallback]
		private bool logical_not (bool value) {
			return !value;
		}

		[GtkCallback]
		private bool logical_or (bool a, bool b) {
			return a || b;
		}

		private void populate_os_list () {
			primary_os_list.remove_all ();
			other_os_list.remove_all ();

			Gee.ArrayList<Osinfo.Os> filtered = os_list;
			foreach (var filter in filters.values)
				filtered = filter.filter (filtered);

			foreach (var os in filtered) {
				var row = new Adw.ActionRow ();
				row.title = os.get_name () ?? os.get_short_id ();
				row.subtitle = os.get_vendor () ?? "";

				if (os.get_distro () == primary_distro)
					primary_os_list.append (row);
				else
					other_os_list.append (row);
			}
		}

		private void populate_dropdown (
			Gtk.DropDown widget,
			Gee.TreeSet<string> items,
			string title
		) {
			var string_list = new Gtk.StringList (null);
			string_list.append (title);
			foreach (var item in items)
				string_list.append (item);

			widget.model = string_list;
			widget.notify["selected"].connect (() => {
				var index = widget.selected;
				if (index == 0) {
					filters[title] = new OsFilter ();
				} else {
					filters[title].title = title;
					filters[title].filter_str = items.to_array ()[index - 1];
				}
				populate_os_list ();
			});
		}
	}
}
