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

		private ListStore primary_store = new ListStore (typeof (DownloadPageRow));
		private ListStore other_store = new ListStore (typeof (DownloadPageRow));
		private Gee.ArrayList<string> arches_list = new Gee.ArrayList<string> ();

		private Gtk.FilterListModel primary_model;
		private Gtk.FilterListModel other_model;

		private Gtk.CustomFilter row_filter = null;

		private string? arch_filter = null;
		private string search_query = "";

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

		public void populate () {
			primary_os_label.label = primary_os_title;

			primary_store.remove_all ();
			other_store.remove_all ();
			arches_list.clear ();

			var families = new Gee.ArrayList<OsFamily> ();
			families.add_all (service.osinfo.families.values);
			families.sort ((a, b) => strcmp (a.name, b.name));

			foreach (var family in families) {
				if (family.primary) {
					foreach (var edition in service.osinfo.get_primary_editions (family))
						primary_store.append (new DownloadPageRow.primary (family, edition));
				} else {
					other_store.append (new DownloadPageRow.other (family));
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

		private void setup_models () {
			row_filter = new Gtk.CustomFilter ((obj) => {
				var row = obj as DownloadPageRow;
				return row_arch_matches (row) && search_matches (row.title);
			});

			primary_model = new Gtk.FilterListModel (primary_store, row_filter);
			other_model = new Gtk.FilterListModel (other_store, row_filter);

			primary_os_list.bind_model (primary_model, (obj) => (Gtk.Widget) obj);
			other_os_list.bind_model (other_model, (obj) => (Gtk.Widget) obj);
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

			arch_filter = arches_list.contains (service.host_arch) ? service.host_arch : arches_list[0];
			arch_dropdown.selected = (uint) arches_list.index_of (arch_filter);
		}

		private void on_filter_changed () {
			row_filter.changed (Gtk.FilterChange.DIFFERENT);
			update_box_visibility ();
		}

		private void update_box_visibility () {
			primary_os_box.visible = primary_model.n_items > 0;
			other_os_box.visible = other_model.n_items > 0;
		}

		private bool row_arch_matches (DownloadPageRow row) {
			if (arch_filter == null)
				return true;

			if (row.is_primary)
				return edition_arches_matches (row.edition);

			foreach (var version in row.family.versions.values) {
				foreach (var edition in version.editions.values) {
					if (edition_arches_matches (edition))
						return true;
					else
						continue;
				}
			}

			return false;
		}

		private bool edition_arches_matches (OsEdition edition) {
			foreach (var image in edition.images) {
				if (image.arch == arch_filter || image.arch == null)
					return true;
			}

			return false;
		}

		private bool search_matches (string text) {
			if (search_query == "")
				return true;

			return text.down ().contains (search_query.down ());
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
		private void configure_os_page (Gtk.ListBoxRow list_row) {
			var row = (DownloadPageRow) list_row;
			var view = (Adw.NavigationView) get_ancestor (typeof (Adw.NavigationView));
			var page = (OsPage) view.find_page ("os-page");

			page.configure (row.family, row.edition);
			view.push (page);
		}
	}
}
