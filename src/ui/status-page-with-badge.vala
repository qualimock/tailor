/* status-page-with-badge.vala
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

	[GtkTemplate (ui = "/org/altlinux/Tailor/status-page-with-badge.ui")]
	public class StatusPageWithBadge : Adw.Bin {

		[GtkChild] private unowned Adw.StatusPage statuspage;

		public string title { get; set; }
		public string description { get; set; }
		public string badge { get; set; }
		public string icon_name { get; set; default=""; }
		public bool compact { get; set; default=false; }
		public bool badge_visible { get; set; default=true; }

		[GtkCallback]
		private void switch_compact () {
			if (compact) {
				statuspage.add_css_class ("compact");
			} else {
				statuspage.remove_css_class ("compact");
			}
		}
	}
}
