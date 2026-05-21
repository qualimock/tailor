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
		public Gee.HashMap<string, Gee.ArrayList<Os>> fresh { get; private set; }
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

		public Gee.HashMap<string, Os> get_fresh_oses () {
			var fresh = new Gee.HashMap<string, Os> ();
			foreach (var distro in distros) {
				var key = distro.id + "/" + distro.arch;
				if (!fresh.has_key (key)) {
					fresh.set (key, distro);
					continue;
				}

				double current = double.parse (distro.version);
				double contained = double.parse (fresh.get (key).version);

				if (current > contained)
					fresh[key] = distro;
			}

			return fresh;
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
