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

		[GtkChild] private unowned Gtk.Box primary_os_box;
		[GtkChild] private unowned Gtk.Label primary_os_label;
		[GtkChild] private unowned Gtk.ListBox primary_os_list;

		[GtkChild] private unowned Gtk.Box other_os_box;
		[GtkChild] private unowned Gtk.ListBox other_os_list;

		[GtkChild] private unowned Gtk.DropDown arch_dropdown;

		private Gee.ArrayList<Osinfo.Os> os_list;

		private string primary_distro = "";
		private string? arch_filter = null;
		private string search_query = "";

		construct {
			var application = (Tailor.Application) GLib.Application.get_default ();

			primary_distro = application.settings.get_string ("primary-os");
			primary_os_label.label = application.settings.get_string ("primary-os-title");

			var future = Dex.thread_spawn ("osinfo-loader", load_db);
			var chain = new Dex.Future.then (future, init);
			chain = new Dex.Future.catch (chain, load_error);
			chain.disown ();
		}

		[GtkCallback] private bool logical_not (bool value) { return !value; }
		[GtkCallback] private bool logical_or (bool a, bool b) { return a || b; }

		private Dex.Future load_db () {
			try {
				var db = OsinfoLoader.load_db ();
				os_list = OsinfoLoader.get_os_list (db);
				return new Dex.Future.for_boolean (true);
			} catch (Error e) {
				return new Dex.Future.for_error (e);
			}
		}

		private Dex.Future init () {
			spinner.visible = false;

			populate_arch_dropdown ();
			populate_os_list ();

			primary_os_list.set_filter_func (search_filter_cb);
			other_os_list.set_filter_func (search_filter_cb);

			search_entry.changed.connect (on_search_changed);

			return new Dex.Future.for_boolean (true);
		}

		private Dex.Future load_error (Dex.Future future) {
			try {
				future.get_value ();
			} catch (Error e) {
				warning ("Failed to load OS database: %s", e.message);
			}

			spinner.visible = false;
			download_error.visible = true;
			return new Dex.Future.for_boolean (false);
		}

		private bool search_filter_cb (Gtk.ListBoxRow row) {
			var row_title = ((Adw.ActionRow) row).title.down ();
			if (row_title.contains (search_query.down ()))
				return true;

			return false;
		}

		private bool list_has_visible_rows (Gtk.ListBox list) {
			var row = list.get_row_at_index (0);

			int i = 0;
			while (row != null) {
				if (row.get_child_visible ()) return true;
				row = list.get_row_at_index (++i);
			}

			return false;
		}

		private void update_box_visibility () {
			primary_os_box.visible = list_has_visible_rows (primary_os_list);
			other_os_box.visible = list_has_visible_rows (other_os_list);
		}

		private void on_search_changed () {
			search_query = search_entry.text;

			primary_os_list.invalidate_filter ();
			other_os_list.invalidate_filter ();

			update_box_visibility ();
		}

		private bool os_has_arch (Osinfo.Os os, string? arch) {
			if (arch == null) return true;

			foreach (var entity in os.get_media_list ().get_elements ()) {
				var a = ((Osinfo.Media) entity).get_architecture ();

				if (a == arch || a == "all") return true;
			}

			return false;
		}

		private void populate_os_list () {
			primary_os_list.remove_all ();
			other_os_list.remove_all ();

			var filtered = new Gee.ArrayList<Osinfo.Os> ();
			foreach (var os in os_list)
				if (os_has_arch (os, arch_filter)) filtered.add (os);

			foreach (var os in filtered) {
				var row = new Adw.ActionRow ();
				row.title = os.get_name () ?? os.get_short_id ();
				row.subtitle = os.get_vendor () ?? "";

				if (os.get_distro () == primary_distro)
					primary_os_list.append (row);
				else
					other_os_list.append (row);
			}

			update_box_visibility ();
		}

		private void populate_arch_dropdown () {
			var model = new Gtk.StringList (null);
			var arches = OsinfoLoader.get_arch_list (os_list);

			foreach (var arch in arches)
				model.append (arch);

			arch_dropdown.model = model;

			uint default_index = 0;
			var arr = arches.to_array ();
			for (uint i = 0; i < arr.length; i++) {
				if (arr[i] == Posix.utsname ().machine) {
					default_index = i;
					break;
				}
			}

			arch_filter = arr.length > 0 ? arr[default_index] : null;
			arch_dropdown.selected = default_index;

			arch_dropdown.notify["selected"].connect (() => {
				var index = arch_dropdown.selected;
				arch_filter = arches.to_array ()[index];
				populate_os_list ();
			});
		}
	}
}
