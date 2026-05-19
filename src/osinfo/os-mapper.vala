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

		public static Os os_from_osinfo (Osinfo.Os os, Osinfo.Media media, string primary_distro) {

			var dto = new Os (get_os_id (os, media));
			dto.display_name = get_os_display_name (os, media);
			dto.variant = os.vendor;
			dto.version = os.version;
			dto.arch = media.get_architecture ();
			dto.family = os.distro.down ();
			dto.vendor = os.vendor;
			dto.url = media.get_url ();
			dto.primary = (os.distro == primary_distro);
			return dto;
		}

		public static OsFamily family_from_osinfo (Osinfo.Os os, string primary_distro) {
			var dto = new OsFamily (os.distro, os.vendor);
			dto.primary = (os.distro == primary_distro);
			dto.display_name = get_family_display_name (os);
			return dto;
		}

		private static string get_family_display_name (Osinfo.Os os) {
			const string[] SUFFIXES = {
				"testing", "unstable", "stable",
				"rolling", "rawhide", "unknown",
				"factory", "tumbleweed", "latest",
				"beta", "nightly"
			};

			var name = os.name;
			for (int i = 0; i < name.length - 1; i++) {
				if (name[i] == ' ' && name[i + 1].isdigit ())
					return name[0:i];
			}

			int last_space = name.last_index_of (" ");
			if (last_space >= 0) {
				var last_word = name[last_space + 1:].down ();
				foreach (var word in SUFFIXES) {
					if (word in last_word)
						return name[0:last_space].strip ();
				}
			}

			return name.strip ();
		}

		private static string get_os_id (Osinfo.Os os, Osinfo.Media media) {
			const string[] SUFFIXES = { "-netinst", "-netinstall", "-live", "-dvd" };

			var variants = media.get_os_variants ().get_elements ();
			var id = os.id;

			if (variants.is_empty ())
				return id[0:id.last_index_of ("/")];

			id = ((Osinfo.OsVariant) variants.nth_data (0)).id;

			foreach (var suffix in SUFFIXES) {
				if (id.has_suffix (suffix))
					return id[0:id.length - suffix.length];
			}

			return id;
		}

		private static string get_os_display_name (Osinfo.Os os, Osinfo.Media media) {
			var variants = media.get_os_variants ().get_elements ();
			var name = variants.is_empty ()
				? null
				: ((Osinfo.OsVariant) variants.nth_data (0)).get_name ();

			return name ??
			       os.name ??
			       os.distro ??
			       os.short_id ??
			       "Unknown";
		}
	}
}
