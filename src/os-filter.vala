/* os-filter.vala
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

	internal class OsFilter {

		public string title { get; set; }
		public string filter_str { get; set; }

		private bool os_has_arch (Osinfo.Os os, string? arch) {
			if (arch == null) return true;

			foreach (var entity in os.get_media_list ().get_elements ()) {
				var a = ((Osinfo.Media) entity).get_architecture ();

				if (a == arch || a == "all") return true;
			}

			return false;
		}

		public Gee.ArrayList<Osinfo.Os> filter (Gee.ArrayList<Osinfo.Os> list) {
			OsFilterPredicate predicate;

			switch (title) {
			case "Architecture":
				predicate = (os, arch) => os_has_arch (os, arch);
				break;
			case "Distribution":
				predicate = (os, distro) => os.get_distro () == distro;
				break;
			default:
				return list;
			}

			var filtered = new Gee.ArrayList<Osinfo.Os> ();
			var it = list.filter (
				(os) => predicate (os, filter_str)
			);
			while (it.next ()) {
				filtered.add (it.get ());
			}

			return filtered;
		}
	}

	delegate bool OsFilterPredicate (Osinfo.Os os, string filter);
}
