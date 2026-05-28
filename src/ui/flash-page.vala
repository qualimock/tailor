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

		[GtkChild] private unowned StatusPageWithBadge os_statuspage;
		[GtkChild] private unowned StatusLine download_status;

		public ServiceContext service { get; construct set; }
		private UsbDevice device { get; set; }

		static construct {
			typeof (StatusLine).ensure ();
			typeof (ProgressLine).ensure ();
		}

		[GtkCallback]
		private string fraction_to_string (double value) {
			return (value * 100).to_string ();
		}

		public void configure_from_image (File image, UsbDevice device) {
			os_statuspage.title = "%s".printf (image.get_basename ());
			os_statuspage.icon_name = "media-optical-symbolic";
			os_statuspage.description = _("Local file");

			try {
				var info = image.query_info (
					FileAttribute.STANDARD_SIZE, FileQueryInfoFlags.NONE
				);
				os_statuspage.badge = format_size (info.get_size ());
			} catch (Error e) {
				os_statuspage.badge_visible = false;
			}

			download_status.visible = false;
			this.device = device;
		}

		public void configure_from_os (OsFamily family, Os os, UsbDevice device) {
			os_statuspage.title = "%s %s %s %s".printf (
				family.display_name,
				os.edition ?? "",
				os.version ?? "",
				os.codename != null ? "(%s)".printf (os.codename) : ""
			);

			os_statuspage.description = family.vendor;
			os_statuspage.badge = os.arch;

			download_status.title = _("Downloading image %s").printf (Path.get_basename (os.url));
			this.device = device;
		}
	}
}
