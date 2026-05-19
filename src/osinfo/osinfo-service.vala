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

		private OsinfoProvider provider;

		public Gee.ArrayList<OsDto> oses { get; private set; }
		public Gee.TreeSet<string> arches { get; private set; }

		public OsinfoService () {
			provider = new OsinfoProvider ();
			oses = new Gee.ArrayList<OsDto> ();
			arches = new Gee.TreeSet<string> ();
		}

		public signal void loaded ();
		public signal void load_failed (Error e);

		public async void load (string primary_distro) {
			try {
				yield provider.load ();
			} catch (Error e) {
				load_failed (e);
				return;
			}

			oses.clear ();
			arches.clear ();

			var os_list = provider.get_os_list ();
			var superseded = get_superseded_oses (os_list);

			foreach (var os in os_list) {
				if (!is_eligible (os, superseded) || !is_downloadable (os))
					continue;

				var os_dto = OsMapper.from_osinfo (os, primary_distro);

				oses.add (os_dto);
				arches.add_all (os_dto.arches);
			}

			loaded ();
		}

		private bool is_downloadable (Osinfo.Os os) {
			bool downloadable = false;

			foreach (var entity in os.get_media_list ().get_elements ()) {
				var media = (Osinfo.Media) entity;
				if (media.get_url () != null) {
					downloadable = true;
					break;
				}
			}

			return downloadable;
		}

		private bool is_eligible (Osinfo.Os os, Gee.HashSet<string> superseded) {
			return !superseded.contains (os.get_id ()) &&
			        os.get_param_value ("eol-date") == null &&
			        os.get_distro () != null;
		}

		private Gee.HashSet<string> get_superseded_oses (Gee.ArrayList<Osinfo.Os> os_list) {
			var superseded = new Gee.HashSet<string> ();

			foreach (var entity in os_list) {
				var osinfo_os = (Osinfo.Os) entity;
				var upgrades = osinfo_os.get_related (Osinfo.ProductRelationship.UPGRADES);

				foreach (var older in upgrades.get_elements ())
					superseded.add (older.get_id ());
			}

			return superseded;
		}
	}
}
