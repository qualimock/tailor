/* os-page.vala
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

	[GtkTemplate (ui = "/org/altlinux/Tailor/os-page.ui")]
	public class OsPage : Adw.NavigationPage {

		[GtkChild] private unowned Gtk.DropDown edition_dropdown;
		[GtkChild] private unowned Gtk.DropDown version_dropdown;
		[GtkChild] private unowned Gtk.DropDown arch_dropdown;
		[GtkChild] private unowned Gtk.DropDown devices_dropdown;

		[GtkChild] private unowned Gtk.Label cpu_label;
		[GtkChild] private unowned Gtk.Label ram_label;
		[GtkChild] private unowned Gtk.Label free_space_label;

		[GtkChild] private unowned Gtk.Label size_label;
		[GtkChild] private unowned Gtk.Label release_label;
		[GtkChild] private unowned Gtk.Label media_type_label;
		[GtkChild] private unowned Gtk.Label codename_label;

		private ServiceContext _service;
		public ServiceContext service {
			get { return _service; }
			set {
				if (_service != null) {
					_service.usb.device_added.disconnect (add_device);
					_service.usb.device_removed.disconnect (remove_device);
				}
				_service = value;
				if (value == null)
					return;

				value.usb.device_added.connect (add_device);
				value.usb.device_removed.connect (remove_device);
			}
		}

		public bool has_editions { get; private set; default = false; }
		public bool has_versions { get; private set; default = false; }
		public bool has_arches { get; private set; default = false; }
		public bool has_requirements { get; private set; default = false; }

		public string? selected_edition { get; set; }
		public string? selected_version { get; set; }
		public string? selected_arch { get; set; }

		private OsFamily current_family { get; private set; }
		private Os current_os { get; private set; }

		private ListStore device_store = new ListStore (typeof (UsbDevice));
		private bool updating = false;

		[GtkCallback]
		private string stringify (Gtk.StringObject? obj) {
			return obj?.string ?? "";
		}

		[GtkCallback]
		private bool greater_than (uint a, uint b) { return a > b; }

		[GtkCallback]
		private string requirements_subtitle (bool has) {
			return has ? "" : _("Not available");
		}

		[GtkCallback]
		private bool is_not_empty_string (string str) { return str.length > 0; }

		[GtkCallback]
		private bool any (int count, ...) {
			var args = va_list ();

			for (int i = 0; i < count; i++) {
				if (args.arg<bool> ()) return true;
			}

			return false;
		}

		[GtkCallback]
		private void open_flash_page () {
			var view = (Adw.NavigationView) get_ancestor (typeof (Adw.NavigationView));
			var page = (FlashPage) view.find_page ("flash-page");
			page.configure_from_os (current_family, current_os);
			view.push (page);
		}

		construct {
			devices_dropdown.model = new Gtk.SingleSelection (device_store);
			devices_dropdown.expression = new Gtk.PropertyExpression (typeof (UsbDevice), null, "name");
		}

		public void add_device (UsbDevice device) {
			device_store.append (device);
		}

		public void remove_device (string object_path) {
			var match = service.usb.devices.first_match (
				d => d.object_path == object_path
			);

			uint index;
			if (device_store.find (match, out index))
				device_store.remove (index);
		}

		private static string format_hertz (int64 hz) {
			if (hz < Osinfo.MEGAHERTZ * 1000)
				return _("%.0f MHz").printf ((double) hz / Osinfo.MEGAHERTZ);

			return _("%.1f GHz").printf ((double) hz / (Osinfo.MEGAHERTZ * 1000));
		}

		private static string format_bytes (int64 bytes) {
			if (bytes < Osinfo.GIBIBYTES)
				return _("%.0f MiB").printf ((double) bytes / Osinfo.MEBIBYTES);

			return _("%.1f GiB").printf ((double) bytes / Osinfo.GIBIBYTES);
		}

		private void update_os_info (Os os) {
			has_requirements = os.resources.cpu > 0 ||
			                   os.resources.ram > 0 ||
			                   os.resources.storage > 0;

			cpu_label.label = os.resources.cpu > 0
				? format_hertz (os.resources.cpu)
				: _("Not available");

			ram_label.label = os.resources.ram > 0
				? format_bytes (os.resources.ram)
				: _("Not available");

			free_space_label.label = os.resources.storage > 0
				? format_bytes (os.resources.storage)
				: _("Not available");

			size_label.label = os.volume_size > 0 ? format_bytes (os.volume_size) : "";
			release_label.label = os.release_date ?? "";
			media_type_label.label = os.media_type ?? "";
			codename_label.label = os.codename ?? "";

			current_os = os;
		}

		public void configure (OsFamily family, Os selected) {
			current_family = family;
			title = family.display_name;
			updating = true;

			var editions = new Gee.TreeSet<string> ();
			editions.add_all (family.editions.keys);
			editions.remove ("");

			has_editions = !editions.is_empty;
			if (has_editions)
				populate_dropdown (edition_dropdown, editions, selected.edition ?? "");

			populate_versions (selected.edition ?? "", selected.version ?? "");
			populate_arches (selected.edition ?? "", selected.version ?? "", selected.arch ?? "");

			update_os_info (selected);

			updating = false;
		}

		[GtkCallback]
		private void on_edition_selected () {
			if (updating)
				return;

			populate_versions (selected_edition ?? "", selected_version ?? "");
		}

		[GtkCallback]
		private void on_version_selected () {
			if (updating)
				return;

			populate_arches (selected_edition ?? "", selected_version ?? "", selected_arch ?? "");
		}

		[GtkCallback]
		private void on_arch_selected () {
			if (updating)
				return;

			var os = find_selected_os ();
			if (os != null)
				update_os_info (os);
		}

		private void populate_versions (string edition, string preferred) {
			has_versions = false;

			if (current_family == null || !current_family.editions.has_key (edition))
				return;

			var versions = new Gee.TreeSet<string> ();
			versions.add_all (current_family.editions[edition].keys);
			versions.remove ("");

			has_versions = !versions.is_empty;
			if (!has_versions)
				return;

			var selected = versions.contains (preferred) ? preferred : versions.first ();
			populate_dropdown (version_dropdown, versions, selected);
		}

		private Os? find_selected_os () {
			return current_family.distros.first_match (os =>
				(os.edition ?? "") == (selected_edition ?? "") &&
				(os.version ?? "") == (selected_version ?? "") &&
				(os.arch ?? "") == (selected_arch ?? "")
			);
		}

		private void populate_arches (string edition, string version, string preferred) {
			has_arches = false;

			if (current_family == null || !current_family.editions.has_key (edition))
				return;

			var edition_versions = current_family.editions[edition];
			if (!edition_versions.has_key (version))
				return;

			var arches = new Gee.TreeSet<string> ();
			arches.add_all (edition_versions[version]);
			arches.remove ("");

			has_arches = !arches.is_empty;
			if (!has_arches)
				return;

			var selected = arches.contains (preferred) ? preferred : arches.first ();

			populate_dropdown (arch_dropdown, arches, selected);
		}

		private void populate_dropdown (Gtk.DropDown dropdown, Gee.TreeSet<string> items, string selected) {
			var model = new Gtk.StringList (null);
			uint i = 0;
			uint selected_idx = Gtk.INVALID_LIST_POSITION;

			foreach (var item in items) {
				model.append (item);
				if (selected != null && item == selected)
					selected_idx = i;

				i++;
			}

			dropdown.model = model;
			dropdown.expression = new Gtk.PropertyExpression (typeof (Gtk.StringObject), null, "string");
			if (selected_idx != Gtk.INVALID_LIST_POSITION)
				dropdown.selected = selected_idx;
		}
	}
}
