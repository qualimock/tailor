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

	public class OsinfoResult : Object {
		public Gee.ArrayList<OS> oses { get; construct set; }
		public Gee.TreeSet<string> arches { get; construct set; }

		public OsinfoResult (Gee.ArrayList<OS> oses, Gee.TreeSet<string> arches) {
			Object (oses: oses, arches: arches);
		}
	}

	public class OsinfoService {

		private OsinfoRepository repo;

		public OsinfoResult init (string primary_distro) throws Error {
			repo = new OsinfoRepository ();
			var oses = repo.init (primary_distro);

			var arches = new Gee.TreeSet<string> ();
			foreach (var os in oses)
				arches.add_all (os.arches);

			return new OsinfoResult (oses, arches);
		}
	}
}
