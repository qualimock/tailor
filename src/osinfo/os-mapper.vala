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
			dto.edition = get_os_edition (dto, os, media);
			dto.version = os.version;
			dto.arch = media.architecture;
			dto.family = os.distro;
			dto.vendor = os.vendor;
			dto.url = media.get_url ();
			dto.primary = (os.distro == primary_distro);

			var resources = os.get_minimum_resources ().get_elements ();
			Osinfo.Resources matched = null;
			foreach (var entity in resources) {
				var resource = (Osinfo.Resources) entity;

				if (resource.architecture == media.architecture)
					matched = resource;

				if (resource.architecture == Osinfo.ARCHITECTURE_ALL && matched == null)
					matched = resource;
			}

			if (matched != null) {
				dto.resources = OsResources () {
					cpu = matched.cpu,
					ram = matched.ram,
					storage = matched.storage
				};
			}

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

		private static Osinfo.OsVariant get_os_variant (Osinfo.Os os, Osinfo.Media media) {
			var variants = media.get_os_variants ().get_elements ();

			return variants.is_empty ()
				? null
				: (Osinfo.OsVariant) variants.nth_data (0);
		}

		private static string strip_parens (string str) {
			var parts = new Gee.ArrayList<string> ();

			foreach (var token in str.split (" ")) {
				if (!token.has_prefix ("("))
					parts.add (token);
			}

			return string.joinv (" ", parts.to_array ()).strip ();
		}

		private static string get_os_display_name (Osinfo.Os os, Osinfo.Media media) {
			var fallback = os.name ?? os.distro ?? os.short_id ?? "Unknown";
			var variant = get_os_variant (os, media);

			if (variant != null)
				return strip_parens (variant.name ?? fallback);

			return strip_parens (fallback);
		}

		private static string? get_os_edition (Os dto, Osinfo.Os os, Osinfo.Media media) {
			var variant = get_os_variant (os, media);
			if (variant == null) {
				var family_display = get_family_display_name (os);
				var parts = family_display.split (" ", 2);
				if (parts.length > 1 && parts[0].down () == os.distro.down ())
					return parts[1];

				return null;
			}

			var variant_name = variant.name;
			if (variant_name == null)
				return null;

			var os_tokens = new Gee.HashSet<string> ();
			if (os.name != null) {
				foreach (var t in os.name.split (" "))
					os_tokens.add (t);
			}

			var edition_parts = new Gee.ArrayList<string> ();
			foreach (var token in variant_name.split (" ")) {
				if (!os_tokens.contains (token) && !token.has_prefix ("("))
					edition_parts.add (token);
			}

			var edition = string.joinv (" ", edition_parts.to_array ()).strip ();
			return edition.length > 0 ? edition : null;
		}
	}
}
