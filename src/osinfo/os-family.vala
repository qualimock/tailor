/* os-family.vala
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

	public class OsFamily : Object {

		public string family { get; construct; }
		public string vendor { get; construct; }
		public string display_name { get; set; }
		public bool primary { get; set; }
		public Gee.ArrayList<Os> distros { get; private set; }
		public Gee.HashMap<
			string,
			Gee.HashMap<string, Gee.TreeSet<string>>
		> editions { get; private set; }

		public OsFamily (string family, string vendor) {
			Object (
				family: family,
				vendor: vendor
			);

			distros = new Gee.ArrayList<Os> ();
		}

		private static int compare_versions (string? a, string? b) {
			var a_parts = (a ?? "0").split (".");
			var b_parts = (b ?? "0").split (".");
			var len = int.max (a_parts.length, b_parts.length);

			for (int i = 0; i < len; i++) {
				var a_value = i < a_parts.length ? int.parse (a_parts[i]) : 0;
				var b_value = i < b_parts.length ? int.parse (b_parts[i]) : 0;
				if (a_value != b_value)
					return a_value - b_value;
			}

			return 0;
		}

		public Gee.HashMap<string, Os> get_fresh_oses () {
			var fresh = new Gee.HashMap<string, Os> ();
			foreach (var distro in distros) {
				var key = distro.id + "/" + distro.arch;
				if (!fresh.has_key (key)) {
					fresh.set (key, distro);
					continue;
				}

				var contained = fresh.get (key);
				int version_cmp = compare_versions (distro.version, contained.version);

				if (version_cmp != 0) {
					if (version_cmp > 0)
						fresh[key] = distro;

					continue;
				}

				var distro_date = distro.release_date ?? "";
				var contained_date = contained.release_date ?? "";
				if (strcmp (distro_date, contained_date) > 0)
					fresh[key] = distro;
			}

			return fresh;
		}

		public Os? get_preferred_os (string? preferred_arch, string arch_fallback) {
			Os? pick = null;

			var arch = preferred_arch ?? arch_fallback;
			foreach (var os in get_fresh_oses ().values) {
				if (os.arch == arch) { pick = os; break; }
				if (pick == null) pick = os;
			}

			return pick;
		}

		public void build_index () {
			editions = new Gee.HashMap<string, Gee.HashMap<string, Gee.TreeSet<string>>> ();

			foreach (var os in distros) {
				var edition = os.edition ?? "";
				var version = os.version ?? "";

				if (!editions.has_key (edition))
					editions[edition] = new Gee.HashMap<string, Gee.TreeSet<string>> ();

				if (!editions[edition].has_key (version))
					editions[edition][version] = new Gee.TreeSet<string> ();

				if (os.arch != null)
					editions[edition][version].add (os.arch);
			}
		}
	}
}
