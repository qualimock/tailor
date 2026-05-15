/* osinfo-service.vala
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

	public class OsinfoService {

		public static Gee.ArrayList<Osinfo.Os> load_os_list () throws Error {
			return get_os_list (OsinfoRepository.load_db ());
		}

		private static Gee.ArrayList<Osinfo.Os> get_os_list (Osinfo.Db db) {
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

		public static Gee.ArrayList<string> get_arch_list (Gee.ArrayList<Osinfo.Os> os_list) {
			var arches = new Gee.TreeSet<string> ();
			var arches_list = new Gee.ArrayList<string> ();

			foreach (var os in os_list)
				foreach (var entity in os.get_media_list ().get_elements ()) {
					var media = (Osinfo.Media) entity;
					var arch = media.get_architecture ();
					if (arch != null && arch != "all") arches.add (arch);
				}

			arches_list.add_all (arches);
			return arches_list;
		}

		public static Gee.ArrayList<string> get_distro_list (Gee.ArrayList<Osinfo.Os> os_list) {
			var distros = new Gee.TreeSet<string> ();
			var distros_list = new Gee.ArrayList<string> ();

			foreach (var os in os_list) {
				var distro = os.get_distro ();
				if (distro != null) distros.add (distro);
			}

			distros_list.add_all (distros);
			return distros_list;
		}

		public static Gee.ArrayList<Osinfo.Os> filter_by_arch (Gee.ArrayList<Osinfo.Os> list, string? filter) {
			var filtered = new Gee.ArrayList<Osinfo.Os> ();

			foreach (var os in list)
				if (os_matches_arch (os, filter)) filtered.add (os);

			return filtered;
		}

		public static void split_by_distro (
			Gee.ArrayList<Osinfo.Os> list,
			string distro,
			out Gee.ArrayList<Osinfo.Os> primary,
			out Gee.ArrayList<Osinfo.Os> other
		) {
			primary = new Gee.ArrayList<Osinfo.Os> ();
			other = new Gee.ArrayList<Osinfo.Os> ();

			foreach (var os in list) {
				if (os.get_distro () == distro)
					primary.add (os);
				else
					other.add (os);
			}
		}

		private static bool os_matches_arch (Osinfo.Os os, string? arch) {
			if (arch == null) return true;

			foreach (var entity in os.get_media_list ().get_elements ()) {
				var a = ((Osinfo.Media) entity).get_architecture ();

				if (a == arch || a == "all") return true;
			}

			return false;
		}
	}
}
