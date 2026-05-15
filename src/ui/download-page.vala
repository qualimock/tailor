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

		[GtkChild] private unowned Gtk.Box os_box;
		[GtkChild] private unowned Adw.StatusPage download_error;

		[GtkChild] private unowned Gtk.Entry search_entry;

		[GtkChild] private unowned Gtk.Box primary_os_box;
		[GtkChild] private unowned Gtk.Label primary_os_label;
		[GtkChild] private unowned Gtk.ListBox primary_os_list;

		[GtkChild] private unowned Gtk.Box other_os_box;
		[GtkChild] private unowned Gtk.ListBox other_os_list;

		[GtkChild] private unowned Gtk.DropDown arch_dropdown;

		private Gee.ArrayList<string> arches_list = new Gee.ArrayList<string> ();
		private ListStore os_store = new ListStore (typeof (OS));
		private Gtk.CustomFilter base_filter;
		private string? arch_filter = null;
		private string search_query = "";

		public string primary_os_title { get; construct set; default = ""; }

		private OsinfoService _osinfo_service;
		public OsinfoService osinfo_service {
			get { return _osinfo_service; }
			construct set {
				_osinfo_service = value;
				if (value == null)
					return;

				value.os_added.connect (add_os);
				value.init_succeed.connect (init);
				value.init_failed.connect (init_error);
			}
		}

		[GtkCallback] private bool logical_not (bool value) { return !value; }
		[GtkCallback] private bool logical_or (bool a, bool b) { return a || b; }

		private void init () {
			primary_os_label.label = primary_os_title;

			setup_models ();
			setup_arch_dropdown ();

			os_box.visible = true;

			arch_dropdown.notify["selected"].connect (() => {
				arch_filter = arches_list[(int) arch_dropdown.selected];
				base_filter.changed (Gtk.FilterChange.DIFFERENT);
				update_box_visibility ();
			});

			search_entry.changed.connect (() => {
				search_query = search_entry.text;
				base_filter.changed (Gtk.FilterChange.DIFFERENT);
				update_box_visibility ();
			});

			update_box_visibility ();
		}

		private void init_error (Error e) {
			warning ("Failed to load OS database: %s", e.message);
			download_error.visible = true;
		}

		private void setup_models () {
			base_filter = new Gtk.CustomFilter (matches);
			var base_model = new Gtk.FilterListModel (os_store, base_filter);

			var primary_model = new Gtk.FilterListModel (
				base_model,
				new Gtk.CustomFilter (obj => ((OS) obj).primary)
			);
			var other_model = new Gtk.FilterListModel (
				base_model,
				new Gtk.CustomFilter (obj => !((OS) obj).primary)
			);

			primary_os_list.bind_model (primary_model, make_row);
			other_os_list.bind_model (other_model, make_row);
		}

		private bool matches (Object obj) {
			var os = (OS) obj;
			return arch_matches (os) && search_matches (os);
		}

		private bool arch_matches (OS os) {
			if (arch_filter == null)
				return true;

			return os.arches.contains (arch_filter) || os.arches.is_empty;
		}

		private bool search_matches (OS os) {
			if (search_query == "")
				return true;

			return os.display_name.down ().contains (search_query.down ());
		}

		private Gtk.Widget make_row (Object obj) {
			var os = (OS) obj;

			var row = new Adw.ActionRow ();
			row.title = os.display_name;
			row.subtitle = os.vendor;

			return row;
		}

		public void add_os (OS os) {
			Idle.add (() => {
				os_store.append (os);
				return Source.REMOVE;
			});
		}

		private bool list_has_visible_rows (Gtk.ListBox list) {
			var row = list.get_row_at_index (0);

			for (int i = 0; row != null; ) {
				if (row.get_child_visible ())
					return true;

				row = list.get_row_at_index (++i);
			}

			return false;
		}

		private void update_box_visibility () {
			primary_os_box.visible = list_has_visible_rows (primary_os_list);
			other_os_box.visible = list_has_visible_rows (other_os_list);
		}

		private void setup_arch_dropdown () {
			arches_list.add_all (osinfo_service.arches);

			var model = new Gtk.StringList (null);
			foreach (var arch in arches_list)
				model.append (arch);

			arch_dropdown.model = model;

			string host_arch = Posix.utsname ().machine;
			arch_filter = arches_list.contains (host_arch) ? host_arch : arches_list[0];
			arch_dropdown.selected = (uint) arches_list.index_of (arch_filter);
		}
	}
}
