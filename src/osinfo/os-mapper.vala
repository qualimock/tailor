/* os-mapper.vala
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

	public class OsMapper {

		public static OsDto from_osinfo (Osinfo.Os os, string primary_distro) {
			var dto = new OsDto (os.get_id ());
			dto.display_name = get_os_display_name (os);
			dto.vendor = os.vendor;
			dto.primary = (os.get_distro () == primary_distro);
			dto.arches = get_os_arches (os);
			return dto;
		}

		private static string get_os_display_name (Osinfo.Os os) {
			var name = os.get_name () ??
			           os.get_distro () ??
			           os.get_short_id () ??
			           "Unknown";

			for (int i = 0; i < name.length; i++) {
				if (name[i].isdigit ())
					return name[0:i].strip ();
			}

			return name.strip ();
		}

		private static Gee.ArrayList<string> get_os_arches (Osinfo.Os os) {
			var arches = new Gee.ArrayList<string> ();
			foreach (var element in os.get_media_list ().get_elements ()) {
				var arch = ((Osinfo.Media) element).get_architecture ();
				if (arch != null && arch != "all" && !arches.contains (arch))
					arches.add (arch);
			}

			return arches;
		}
	}
}
