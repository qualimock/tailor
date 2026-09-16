/* ui-service.vala
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

	public class UiService : Object {

		private static Gee.Map<string, string> primary_os_titles;

		public signal void toast_requested (Adw.Toast toast);

		static construct {
			primary_os_titles = new Gee.HashMap<string, string> ();
			var os = _("operating system");
			var family = _("OS family");

			primary_os_titles["alt"] = _("ALT %s").printf (family);
			primary_os_titles["almalinux"] = _("AlmaLinux %s").printf (os);
			primary_os_titles["alpinelinux"] = _("Alpine Linux %s").printf (os);
			primary_os_titles["archlinux"] = _("Arch Linux %s").printf (family);
			primary_os_titles["centos"] = _("CentOS %s").printf (os);
			primary_os_titles["debian"] = _("Debian %s").printf (family);
			primary_os_titles["fedora"] = _("Fedora %s").printf (family);
			primary_os_titles["freebsd"] = _("FreeBSD %s").printf (family);
			primary_os_titles["freedos"] = _("FreeDOS %s").printf (os);
			primary_os_titles["guix-system"] = _("Guix System %s").printf (os);
			primary_os_titles["haiku"] = _("Haiku %s").printf (os);
			primary_os_titles["manjaro"] = _("Manjaro %s").printf (os);
			primary_os_titles["netbsd"] = _("NetBSD %s").printf (os);
			primary_os_titles["nixos"] = _("NixOS %s").printf (os);
			primary_os_titles["openbsd"] = _("OpenBSD %s").printf (os);
			primary_os_titles["opensuse"] = _("openSUSE %s").printf (family);
			primary_os_titles["rocky"] = _("Rocky Linux %s").printf (os);
			primary_os_titles["slackware"] = _("Slackware %s").printf (family);
			primary_os_titles["trisquel"] = _("Trisquel %s").printf (os);
			primary_os_titles["ubuntu"] = _("Ubuntu %s").printf (family);
		}

		public void show_details (Gtk.Widget parent, string title, string message) {
			var dialog = new Adw.AlertDialog (title, message);

			dialog.add_response ("close", _("Close"));
			dialog.add_response ("copy", _("Copy"));

			dialog.set_default_response ("close");
			dialog.set_close_response ("close");

			dialog.response["copy"].connect (() => {
				parent.get_clipboard ().set_text (message);
			});

			dialog.present (parent);
		}

		public string get_primary_os_title (string primary_os_id, string fallback) {
			var id = OsParser.normalize_family_id (primary_os_id);
			return primary_os_titles.has_key (id) ? primary_os_titles[id] : fallback;
		}
	}
}
