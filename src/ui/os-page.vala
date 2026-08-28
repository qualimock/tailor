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

		private ListStore device_store = new ListStore (typeof (UsbDevice));

		private bool repopulating = false;

		[GtkChild] private unowned Gtk.DropDown edition_dropdown;
		[GtkChild] private unowned Gtk.DropDown version_dropdown;
		[GtkChild] private unowned Gtk.DropDown arch_dropdown;
		[GtkChild] private unowned Gtk.DropDown devices_dropdown;

		[GtkChild] private unowned Adw.SwitchRow delete_switch;

		[GtkChild] private unowned Gtk.Label cpu_label;
		[GtkChild] private unowned Gtk.Label ram_label;
		[GtkChild] private unowned Gtk.Label free_space_label;

		[GtkChild] private unowned Gtk.Label size_label;
		[GtkChild] private unowned Gtk.Label release_label;
		[GtkChild] private unowned Gtk.Label media_type_label;
		[GtkChild] private unowned Gtk.Label codename_label;

		public ListStore edition_store { get; private set; }
		public ListStore version_store { get; private set; }
		public ListStore image_store { get; private set; }

		public uint n_editions { get; set; }
		public uint n_versions { get; set; }
		public uint n_arches { get; set; }
		public uint n_devices { get; set; }

		public bool has_requirements { get; private set; default = false; }
		public bool has_checksum { get; set; default = false; }

		public OsFamily current_family { get; private set; }
		public OsEdition? selected_edition { get; set; }
		public OsVersion? selected_version { get; set; }
		public OsImage? selected_image { get; set; }
		public Gtk.SingleSelection? selection_device { get; set; }
		public string logo_icon_name { get; private set; default = ""; }

		public bool checking { get; set; default = true; }
		public bool available { get; set; default = false; }

		private signal void populated ();

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

		construct {
			edition_store = new ListStore (typeof (OsEdition));
			edition_dropdown.model = edition_store;

			version_store = new ListStore (typeof (OsVersion));
			version_dropdown.model = version_store;

			image_store = new ListStore (typeof (OsImage));
			arch_dropdown.model = image_store;

			devices_dropdown.model = new Gtk.SingleSelection (device_store);
			devices_dropdown.expression = new Gtk.PropertyExpression (typeof (UsbDevice), null, "name");

			edition_dropdown.expression = new Gtk.PropertyExpression (typeof (OsEdition), null, "name");
			version_dropdown.expression = new Gtk.PropertyExpression (typeof (OsVersion), null, "version");
			arch_dropdown.expression = new Gtk.PropertyExpression (typeof (OsImage), null, "arch");

			populated.connect (update_os_info);
		}

		public void configure (OsFamily family, OsEdition? preferred_edition) {
			current_family = family;
			populate_editions (preferred_edition?.id);
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

		private void populate_editions (string? preferred_id) {
			repopulating = true;

			if (current_family == null) {
				repopulating = false;
				return;
			}

			var by_id = new Gee.HashMap<string, OsEdition> ();
			foreach (var version in current_family.versions.values) {
				foreach (var edition in version.editions.values)
					by_id.set (edition.id, edition);
			}

			var editions = new Gee.ArrayList<OsEdition> ();
			editions.add_all (by_id.values);
			editions.sort ((a, b) => strcmp (a.name, b.name));

			edition_store.remove_all ();

			uint selected = 0;
			uint index = 0;
			foreach (var edition in editions) {
				edition_store.append (edition);
				if (preferred_id != null && edition.id == preferred_id)
					selected = index;

				index++;
			}

			edition_dropdown.selected = selected;

			populate_versions (null);
		}

		private void populate_versions (string? preferred) {
			if (selected_edition == null) {
				repopulating = false;
				return;
			}

			var versions = new Gee.ArrayList<OsVersion> ();
			foreach (var version in current_family.versions.values) {
				if (version.editions.has_key (selected_edition.id))
					versions.add (version);
			}
			versions.sort ((a, b) => service.osinfo.compare_versions (a.version, b.version));

			version_store.remove_all ();

			uint selected = 0;
			uint index = 0;
			bool found = false;
			foreach (var version in versions) {
				version_store.append (version);
				if (preferred != null && version.version == preferred) {
					selected = index;
					found = true;
				}

				index++;
			}

			if (!found)
				selected = version_store.n_items > 0 ? version_store.n_items - 1 : 0;

			version_dropdown.selected = selected;

			populate_arches (null);
		}

		private void populate_arches (string? preferred) {
			if (selected_version == null) {
				repopulating = false;
				populated ();
				return;
			}

			var edition = selected_version.editions.get (selected_edition.id);
			var images = new Gee.ArrayList<OsImage> ();
			if (edition != null)
				images.add_all (edition.images);

			images.sort ((a, b) => strcmp (a.arch ?? "", b.arch ?? ""));

			image_store.remove_all ();

			uint selected = 0;
			uint index = 0;
			foreach (var image in images) {
				image_store.append (image);
				if (preferred != null && image.arch == preferred)
					selected = index;
				else if (preferred == null && image.arch == service.host_arch)
					selected = index;

				index++;
			}

			arch_dropdown.selected = selected;

			repopulating = false;
			populated ();
		}

		private void update_os_info () {
			if (selected_image == null)
				return;

			var image = selected_image;
			var version = selected_version;

			has_requirements = image.resources.cpu > 0 ||
			                   image.resources.ram > 0 ||
			                   image.resources.storage > 0;

			cpu_label.label = image.resources.cpu > 0
				? format_hertz (image.resources.cpu)
				: _("Not available");

			ram_label.label = image.resources.ram > 0
				? format_bytes (image.resources.ram)
				: _("Not available");

			free_space_label.label = image.resources.storage > 0
				? format_bytes (image.resources.storage)
				: _("Not available");

			size_label.label = image.volume_size > 0
				? format_bytes (image.volume_size)
				: "";

			media_type_label.label = image.media_type ?? "";

			if (version != null) {
				release_label.label = version.release_date ?? "";
				codename_label.label = version.codename ?? "";
			}

			checking = true;
			available = false;
			has_checksum = false;

			image.check_downloadable.begin ((_, res) => {
				available = image.check_downloadable.end (res);

				if (image != selected_image)
					return;

				if (!available) {
					checking = false;
					return;
				}

				image.fetch_checksum.begin (null, (_, res) => {
					image.fetch_checksum.end (res);

					if (image != selected_image)
						return;

					has_checksum = image.checksum != null;
					checking = false;
				});
			});
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

		[GtkCallback]
		private bool greater_than (uint a, uint b) { return a > b; }

		[GtkCallback]
		private bool logical_and (bool a, bool b) { return a && b; }

		[GtkCallback]
		private bool logical_not (bool val) { return !val; }

		[GtkCallback]
		private string string_or_fallback (bool condition, string preferred, string fallback) {
			return condition ? preferred : fallback;
		}

		[GtkCallback]
		private bool is_not_empty_string (string str) { return str.length > 0; }

		[GtkCallback]
		private string delete_subtitle (bool delete_active) {
			if (delete_active)
				return "";

			var downloads_dir = Environment.get_user_special_dir (UserDirectory.DOWNLOAD)
				?? Environment.get_home_dir ();

			return _("Image will be downloaded in %s").printf (downloads_dir);
		}

		[GtkCallback]
		private bool any (int count, ...) {
			var args = va_list ();

			for (int i = 0; i < count; i++) {
				if (args.arg<bool> ()) return true;
			}

			return false;
		}

		[GtkCallback]
		private void on_edition_selected () {
			if (repopulating)
				return;

			repopulating = true;
			populate_versions (null);
		}

		[GtkCallback]
		private void on_version_selected () {
			if (repopulating)
				return;

			repopulating = true;
			populate_arches (null);
		}

		[GtkCallback]
		private void on_arch_selected () {
			if (repopulating)
				return;

			populated ();
		}

		[GtkCallback]
		private void open_flash_page () {
			var view = (Adw.NavigationView) get_ancestor (typeof (Adw.NavigationView));
			var page = (FlashPage) view.find_page ("flash-page");

			if (selection_device == null)
				return;

			var dialog = new Adw.AlertDialog (
				_("Tailor the Image?"),
				_("All device data will be erased!")
			);
			dialog.add_response ("cancel", _("Cancel"));
			dialog.add_response ("proceed", _("Proceed"));

			dialog.set_default_response ("cancel");
			dialog.set_close_response ("cancel");
			dialog.set_response_appearance ("proceed", Adw.ResponseAppearance.DESTRUCTIVE);

			dialog.response["proceed"].connect (() => {
				page.configure_from_os (
					current_family,
					selected_edition, selected_version, selected_image,
					(UsbDevice) selection_device.selected_item,
					delete_switch.active
				);

				view.push (page);
			});

			dialog.present (this);
		}
	}
}
