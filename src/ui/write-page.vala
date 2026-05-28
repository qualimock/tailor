/* write-page.vala
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

	[GtkTemplate (ui = "/org/altlinux/Tailor/write-page.ui")]
	public class WritePage : Adw.Bin {

		public ServiceContext service { get; construct set; }

		static construct {
			typeof (ButtonCard).ensure ();
		}

		[GtkCallback]
		private void open_select_image_dialog () {
			var iso_filter = new Gtk.FileFilter ();
			iso_filter.name = _("ISO Images");
			iso_filter.add_mime_type ("application/x-cd-image");
			iso_filter.add_pattern ("*.iso");
			iso_filter.add_pattern ("*.img");

			var all_filter = new Gtk.FileFilter ();
			all_filter.name = _("All Files");
			all_filter.add_pattern ("*");

			var filters = new GLib.ListStore (typeof (Gtk.FileFilter));
			filters.append (iso_filter);
			filters.append (all_filter);

			var dialog = new Gtk.FileDialog ();
			dialog.title = _("Select Image");
			dialog.filters = filters;
			dialog.default_filter = iso_filter;

			dialog.open.begin (
				(Gtk.Window) this.get_root (),
				null,
				(obj, res) => {
					try {
						service.image_file = dialog.open.end (res);
						var nav = (Adw.NavigationView) get_ancestor (typeof (Adw.NavigationView));
						nav.push_by_tag ("image-page");
					} catch (Error e) {
						if (e.code == Gtk.DialogError.DISMISSED)
							return;

						critical ("Cannot open file: %s", e.message);
					}
				}
			);
		}
	}
}
