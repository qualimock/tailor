/* button-card.vala
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

	[GtkTemplate (ui = "/org/altlinux/Tailor/button-card.ui")]
	public class ButtonCard : Gtk.Button {

		[GtkChild] private unowned Gtk.Label title_label;
		[GtkChild] private unowned Gtk.Label description_label;

		public string title { get; set; }
		public string description { get; set; }
		public new string icon_name { get; set; }
		public bool large { get; set; default = false; }

		private void switch_css_class (Gtk.Label label, string current, string preferred) {
			if (!label.has_css_class (current))
				return;

			label.remove_css_class (current);
			label.add_css_class (preferred);
		}

		[GtkCallback]
		private int get_icon_size (bool is_large) {
			if (is_large)
				return 128;

			return 64;
		}

		[GtkCallback]
		private void resize_labels () {
			if (large) {
				switch_css_class (title_label, "title-4", "title-2");
				description_label.add_css_class ("tl-text-large");
			} else {
				switch_css_class (title_label, "title-2", "title-4");
				description_label.remove_css_class ("tl-text-large");
			}
		}
	}
}
