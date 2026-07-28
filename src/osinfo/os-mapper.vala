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

		public static OsFamily family_from_osinfo (Osinfo.Os os, string primary_distro) {
			var id = OsParser.family_id_from_short_id (os.short_id);
			id = OsParser.normalize_family_id (id);

			var family = new OsFamily (id, os.vendor);

			family.primary = (id == primary_distro);
			family.name = OsParser.get_family_name (os);

			return family;
		}

		public static OsVersion version_from_osinfo (string id, Osinfo.Os os) {
			var version = new OsVersion (id);

			var has_number = (os.version != null && os.version != "");

			version.version = has_number ? os.version : _("Unknown");
			version.has_number = has_number;
			version.release_date = os.get_release_date_string ();
			version.codename = os.codename;

			return version;
		}

		public static OsEdition edition_from_osinfo (Osinfo.Os os, Osinfo.Media media) {
			return new OsEdition (
				OsParser.get_edition_id (os, media),
				OsParser.get_edition_name (os, media)
			);
		}

		public static OsImage image_from_osinfo (Osinfo.Os os, Osinfo.Media media) {
			var image = new OsImage ();

			image.arch = media.architecture;
			image.url = media.url;
			image.volume_size = media.volume_size;
			image.media_type = get_media_type (media);

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
				image.resources = OsResources () {
					cpu = matched.cpu,
					ram = matched.ram,
					storage = matched.storage
				};
			}

			return image;
		}

		private static string? get_media_type (Osinfo.Media media) {
			var live = media.live;
			var installer = media.installer;

			if (live && installer)
				return _("Live + Installer");

			if (live)
				return _("Live");

			if (installer)
				return _("Installer");

			return null;
		}
	}
}
