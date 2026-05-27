/* flash-page.vala
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

	[GtkTemplate (ui = "/org/altlinux/Tailor/flash-page.ui")]
	public class FlashPage : Adw.NavigationPage {

		[GtkChild] private unowned Adw.StatusPage os_statuspage;
		[GtkChild] private unowned Gtk.Label os_info_label;
		[GtkChild] private unowned StatusLine download_status;

		public ServiceContext service { get; construct set; }

		static construct {
			typeof (StatusLine).ensure ();
		}

		[GtkCallback]
		private void on_breakpoint_apply () {
			os_statuspage.add_css_class ("compact");
		}

		[GtkCallback]
		private void on_breakpoint_unapply () {
			os_statuspage.remove_css_class ("compact");
		}

		public void configure_from_image (File image) {
			os_statuspage.title = "%s".printf (image.get_basename ());
			os_statuspage.icon_name = "media-optical-symbolic";
			os_statuspage.description = _("Local file");

			try {
				var info = image.query_info (
					FileAttribute.STANDARD_SIZE, FileQueryInfoFlags.NONE
				);
				os_info_label.label = format_size (info.get_size ());
			} catch (Error e) {
				os_info_label.visible = false;
			}

			download_status.visible = false;
		}

		public void configure_from_os (OsFamily family, Os os) {
			os_statuspage.title = "%s %s %s %s".printf (
				family.display_name,
				os.edition ?? "",
				os.version ?? "",
				os.codename != null ? "(%s)".printf (os.codename) : ""
			);

			os_statuspage.description = family.vendor;
			os_info_label.label = os.arch;

			download_status.title = _("Downloading image %s").printf (Path.get_basename (os.url));
		}
	}
}
