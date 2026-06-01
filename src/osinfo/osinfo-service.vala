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

		private OsinfoProvider provider = new OsinfoProvider ();

		public Gee.HashMap<string, OsFamily> families = new Gee.HashMap<string, OsFamily> ();
		public Gee.TreeSet<string> arches = new Gee.TreeSet<string> ();

		public signal void loaded ();
		public signal void load_failed (Error e);

		public async void load (string primary_distro) {
			try {
				yield provider.load ();
			} catch (Error e) {
				load_failed (e);
				return;
			}

			build_families (primary_distro);

			loaded ();
		}

		private void build_families (string primary_distro) {
			families = new Gee.HashMap<string, OsFamily> ();
			arches = new Gee.TreeSet<string> ();

			foreach (var os in provider.get_os_list ()) {
				if (os.distro == null || is_at_eol (os)) {
					continue;
				}

				var family = build_family (os, primary_distro);
				if (family == null)
					continue;

				if (families.has_key (family.family))
					families[family.family].distros.add_all (family.distros);
				else
					families.set (family.family, family);
			}

			foreach (var family in families.values)
				family.build_index ();
		}

		private OsFamily? build_family (Osinfo.Os os, string primary_distro) {
			var family = OsMapper.family_from_osinfo (os, primary_distro);

			foreach (var entity in os.get_media_list ().get_elements ()) {
				var media = (Osinfo.Media) entity;
				if (media.url == null)
					continue;

				var os_dto = OsMapper.os_from_osinfo (os, media, primary_distro);

				family.distros.add (os_dto);
				if (os_dto.arch != null)
					arches.add (os_dto.arch);
			}

			if (!family.distros.is_empty)
				return family;

			return null;
		}

		// TODO: add OS detection in .iso file

		private bool is_at_eol (Osinfo.Os os) {
			var eol = os.get_eol_date ();
			if (eol == null)
				return false;

			var today = Date ();
			today.set_time_t (time_t ());

			if (eol.compare (today) < 0)
				return true;

			return false;
		}
	}
}
