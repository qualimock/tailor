/* os.vala
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

	public struct OsResources {
		int64 cpu;
		int64 ram;
		int64 storage;
	}

	public class Os : Object {

		public string id { get; construct; }
		public string display_name { get; set; }
		public string edition { get; set; }
		public string version { get; set; }
		public string arch { get; set; }
		public string family { get; set; }
		public string vendor { get; set; }
		public string url { get; set; }
		public bool primary { get; set; }
		public OsResources resources { get; set; }

		// Release and volume info
		public int64 volume_size { get; set; default = -1; }
		public string? media_type { get; set; default = null; }
		public string? release_date { get; set; default = null; }
		public string? codename { get; set; default = null; }

		public Os (string id) {
			Object (id: id);
		}
	}
}
