/* osinfo-loader.vala
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

	public class OsinfoLoader {

		public static Osinfo.Db load_db () throws Error {
			var loader = new Osinfo.Loader ();
			loader.process_default_path ();

			return loader.get_db ();
		}

		public static Gee.ArrayList<Osinfo.Os> get_os_list (Osinfo.Db db) {
			var elements = db.get_os_list ().get_elements ();

			var superseded = new Gee.HashSet<string> ();
			foreach (var entity in elements) {
				var os = (Osinfo.Os) entity;
				var older_list = os.get_related (Osinfo.ProductRelationship.UPGRADES);
				foreach (var older in older_list.get_elements ())
					superseded.add (older.get_id ());
			}

			var result = new Gee.ArrayList<Osinfo.Os> ();
			foreach (var entity in elements) {
				var os = (Osinfo.Os) entity;
				var eol = os.get_param_value ("eol-date");

				if (eol != null) continue;
				if (superseded.contains (os.get_id ())) continue;

				result.add (os);
			}

			return result;
		}

		public static Gee.TreeSet<string> get_arch_list (Gee.ArrayList<Osinfo.Os> os_list) {
			var arches = new Gee.TreeSet<string> ();

			foreach (var os in os_list)
				foreach (var entity in os.get_media_list ().get_elements ()) {
					var media = (Osinfo.Media) entity;
					var arch = media.get_architecture ();
					if (arch != null && arch != "all") arches.add (arch);
				}

			return arches;
		}

		public static Gee.TreeSet<string> get_distro_list (Gee.ArrayList<Osinfo.Os> os_list) {
			var distros = new Gee.TreeSet<string> ();

			foreach (var os in os_list) {
				var distro = os.get_distro ();
				if (distro != null) distros.add (distro);
			}

			return distros;
		}
	}
}
