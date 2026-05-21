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

		[GtkChild] private unowned OsPage os_page;

		[GtkChild] private unowned Adw.NavigationView nav_view;

		[GtkChild] private unowned Gtk.Box os_box;
		[GtkChild] private unowned Adw.StatusPage download_error;

		[GtkChild] private unowned Gtk.Entry search_entry;

		[GtkChild] private unowned Gtk.Box primary_os_box;
		[GtkChild] private unowned Gtk.Label primary_os_label;
		[GtkChild] private unowned Gtk.ListBox primary_os_list;

		[GtkChild] private unowned Gtk.Box other_os_box;
		[GtkChild] private unowned Gtk.ListBox other_os_list;

		[GtkChild] private unowned Gtk.DropDown arch_dropdown;

		public ServiceContext service { get; construct set; }
		public string primary_os_title { get; construct set; default = ""; }

		private ListStore os_store = new ListStore (typeof (Os));
		private ListStore family_store = new ListStore (typeof (OsFamily));
		private Gee.ArrayList<string> arches_list = new Gee.ArrayList<string> ();
		private Gtk.FilterListModel primary_model;
		private Gtk.FilterListModel other_model;
		private Gtk.CustomFilter os_filter = null;
		private Gtk.CustomFilter family_filter = null;
		private string? arch_filter = null;
		private string search_query = "";

		private string host_arch = Posix.utsname ().machine;

		static construct {
			typeof (OsPage).ensure ();
		}

		[GtkCallback] private bool logical_not (bool value) { return !value; }
		[GtkCallback] private bool logical_or (bool a, bool b) { return a || b; }

		[GtkCallback]
		private void on_arch_dropdown_selected () {
			arch_filter = arches_list[(int) arch_dropdown.selected];
			on_filter_changed ();
		}

		[GtkCallback]
		private void on_search_entry_changed () {
			search_query = search_entry.text;
			on_filter_changed ();
		}

		[GtkCallback]
		private void configure_os_page_from_os (Gtk.ListBoxRow row) {
			var os = (Os) primary_model.get_item (row.get_index ());
			var family = service.osinfo.families[os.family];
			os_page.configure (family, os);
			nav_view.push (os_page);
		}

		[GtkCallback]
		private void configure_os_page_from_family (Gtk.ListBoxRow row) {
			var family = (OsFamily) other_model.get_item (row.get_index ());
			Os? pick = null;

			foreach (var os in family.get_fresh_oses ().values) {
				if (os.arch == (string) arch_dropdown.selected_item) { pick = os; break; }
				if (pick == null) pick = os;
			}

			os_page.configure (family, pick);
			nav_view.push (os_page);
		}

		public void populate () {
			primary_os_label.label = primary_os_title;

			os_store.remove_all ();
			family_store.remove_all ();
			arches_list.clear ();

			var families = new Gee.ArrayList<OsFamily> ();
			families.add_all (service.osinfo.families.values);
			families.sort ((a, b) => {
				return strcmp (a.display_name, b.display_name);
			});

			foreach (var family in families) {
				if (family.primary == true) {
					foreach (var os in family.get_fresh_oses ().values)
						os_store.append (os);
				} else {
					family_store.append (family);
				}
			}

			arches_list.add_all (service.osinfo.arches);

			setup_models ();
			setup_arch_dropdown ();

			os_box.visible = true;

			update_box_visibility ();
		}

		public void show_error () {
			download_error.visible = true;
		}

		private void on_filter_changed () {
			os_filter.changed (Gtk.FilterChange.DIFFERENT);
			family_filter.changed (Gtk.FilterChange.DIFFERENT);
			update_box_visibility ();
		}

		private void update_box_visibility () {
			primary_os_box.visible = primary_model.n_items > 0;
			other_os_box.visible = other_model.n_items > 0;
		}

		private void setup_models () {
			os_filter = new Gtk.CustomFilter ((obj) => {
				var os = obj as Os;
				return os_arch_matches (os) && search_matches (os.display_name);
			});
			family_filter = new Gtk.CustomFilter ((obj) => {
				var family = obj as OsFamily;
				return family_arches_matches (family) && search_matches (family.display_name);
			});

			primary_model = new Gtk.FilterListModel (os_store, os_filter);
			other_model = new Gtk.FilterListModel (family_store, family_filter);

			primary_os_list.bind_model (primary_model, make_os_row);
			other_os_list.bind_model (other_model, make_family_row);
		}

		private bool family_arches_matches (OsFamily family) {
			if (arch_filter == null)
				return true;

			bool found = false;
			foreach (var distro in family.distros) {
				if (distro.arch == arch_filter || distro.arch == null)
					found = true;
			}

			return found;
		}

		private bool os_arch_matches (Os os) {
			if (arch_filter == null)
				return true;

			return os.arch == arch_filter || os.arch == null;
		}

		private bool search_matches (string text) {
			if (search_query == "")
				return true;

			return text.down ().contains (search_query.down ());
		}

		private Adw.ActionRow construct_row (string title, string subtitle) {
			var row = new Adw.ActionRow ();
			row.title = title;
			row.subtitle = subtitle;
			row.activatable = true;
			row.selectable = false;
			return row;
		}

		private Adw.ActionRow make_os_row (Object obj) {
			var os = (Os) obj;
			var row = construct_row (os.display_name, os.vendor);
			return row;
		}

		private Adw.ActionRow make_family_row (Object obj) {
			var family = (OsFamily) obj;
			var row = construct_row (family.display_name, family.vendor);
			return row;
		}

		private void setup_arch_dropdown () {
			if (arches_list.is_empty) {
				critical ("Empty arches list");
				return;
			}

			var model = new Gtk.StringList (null);
			foreach (var arch in arches_list)
				model.append (arch);

			arch_dropdown.model = model;

			arch_filter = arches_list.contains (host_arch) ? host_arch : arches_list[0];
			arch_dropdown.selected = (uint) arches_list.index_of (arch_filter);
		}
	}
}
