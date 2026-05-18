/* osinfo-repository.vala
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

	public class OsinfoRepository {

		private string primary_distro;

		public Gee.ArrayList<OS> init (string primary_distro) throws Error {
			this.primary_distro = primary_distro;

			var loader = new Osinfo.Loader ();
			loader.process_default_path ();

			var os_list = loader.get_db ().get_os_list ();
			var superseded_oses = get_superseded_oses (os_list);

			var oses = new Gee.ArrayList<OS> ();
			foreach (var element in os_list.get_elements ()) {
				var os = make_os ((Osinfo.Os) element, superseded_oses);

				if (os != null)
					oses.add (os);
			}

			return oses;
		}

		private Gee.HashSet<string> get_superseded_oses (Osinfo.OsList os_list) {
			var superseded = new Gee.HashSet<string> ();

			foreach (var entity in os_list.get_elements ()) {
				var osinfo_os = (Osinfo.Os) entity;
				var upgrades = osinfo_os.get_related (Osinfo.ProductRelationship.UPGRADES);

				foreach (var older in upgrades.get_elements ())
					superseded.add (older.get_id ());
			}

			return superseded;
		}

		private string get_distro_display_name (Osinfo.Os os) {
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

		private OS? make_os (Osinfo.Os osinfo_os, Gee.HashSet<string> superseded) {
			if (superseded.contains (osinfo_os.get_id ()))
				return null;

			if (osinfo_os.get_param_value ("eol-date") != null)
				return null;

			var os = new OS (osinfo_os.id);
			os.display_name = get_distro_display_name (osinfo_os);
			os.vendor = osinfo_os.vendor;
			os.primary = (osinfo_os.get_distro () == primary_distro);

			var arches = new Gee.ArrayList<string> ();
			foreach (var entity in osinfo_os.get_media_list ().get_elements ()) {
				var arch = ((Osinfo.Media) entity).get_architecture ();
				if (arch != null && arch != "all" && !arches.contains (arch))
					arches.add (arch);
			}
			os.arches = arches;

			return os;
		}
	}
}
