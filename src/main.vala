/* main.vala
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

public static int main (string[] args) {
	var locale_dir = Tailor.LOCALEDIR;
#if WINDOWS
	var root_dir = GLib.Win32.get_package_installation_directory_of_module (null);

	Environment.set_variable ("GSETTINGS_SCHEMA_DIR", root_dir + "\\share\\glib-2.0\\schemas", true);
	Environment.set_variable ("GDK_PIXBUF_MODULEDIR", root_dir + "\\lib\\gdk-pixbuf-2.0\\2.10.0\\loaders", true);
	Environment.set_variable ("GIO_MODULE_DIR", root_dir + "\\lib\\gio\\modules", true);
	Environment.set_variable ("XDG_DATA_DIRS", root_dir + "\\share", true);
	Environment.set_variable ("SSL_CERT_FILE", root_dir + "\\etc\\ssl\\certs\\ca-bundle.crt", true);
	locale_dir = Path.build_filename (root_dir, "share", "locale");
#endif

	Environment.set_prgname (Tailor.ID);
	Intl.setlocale (LocaleCategory.ALL, "");
	Intl.bindtextdomain (Tailor.GETTEXT_PACKAGE, locale_dir);
	Intl.bind_textdomain_codeset (Tailor.GETTEXT_PACKAGE, "UTF-8");
	Intl.textdomain (Tailor.GETTEXT_PACKAGE);

	Environment.set_application_name (_("Tailor"));

	var app = new Tailor.Application ();
	return app.run (args);
}
