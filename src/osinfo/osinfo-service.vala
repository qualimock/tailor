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

		public Gee.ArrayList<OsEdition> get_primary_editions (OsFamily family) {
			var versions = new Gee.ArrayList<OsVersion> ();
			versions.add_all (family.versions.values);
			versions.sort ((a, b) => compare_versions (a.version, b.version));

			var latest = new Gee.HashMap<string, OsEdition> ();
			foreach (var version in versions) {
				foreach (var entry in version.editions.entries)
					latest.set (entry.key, entry.value);
			}

			var result = new Gee.ArrayList<OsEdition> ();
			result.add_all (latest.values);

			return result;
		}

		public int compare_versions (string? a, string? b) {
			var a_parts = (a ?? "0").split (".");
			var b_parts = (b ?? "0").split (".");
			var len = int.max (a_parts.length, b_parts.length);

			for (int i = 0; i < len; i++) {
				var a_value = i < a_parts.length ? int.parse (a_parts[i]) : 0;
				var b_value = i < b_parts.length ? int.parse (b_parts[i]) : 0;
				if (a_value != b_value)
					return a_value - b_value;
			}

			return 0;
		}

		public async OsFamily? detect_os (string image_path) {
			try {
				var media = yield Osinfo.Media.create_from_location_async (
					image_path,
					Priority.DEFAULT,
					new Cancellable ()
				);
				provider.identify_media (media);

				if (media.os == null)
					return null;

				return build_family_for_media (media.os, media);
			} catch (Error e) {
				warning ("Couldn't detect an OS in present path: %s", image_path);
				return null;
			}
		}

		private void build_families (string primary_distro) {
			families = new Gee.HashMap<string, OsFamily> ();
			arches = new Gee.TreeSet<string> ();

			foreach (var os in provider.get_os_list ()) {
				if (is_at_eol (os)) {
					continue;
				}

				var source_family = build_family (os, primary_distro);
				if (source_family == null)
					continue;

				if (!families.has_key (source_family.id)) {
					families.set (source_family.id, source_family);
					continue;
				}

				var target_family = families[source_family.id];

				foreach (var e_version in source_family.versions.entries) {
					var target_version = target_family.versions.get (e_version.key);

					if (target_version == null) {
						target_family.versions.set (e_version.key, e_version.value);
						continue;
					}

					foreach (var e_edition in e_version.value.editions.entries) {
						var target_edition = target_version.editions.get (e_edition.key);

						if (target_edition == null)
							target_version.editions.set (e_edition.key, e_edition.value);
						else
							target_edition.images.add_all (e_edition.value.images);
					}
				}
			}

			foreach (var family in families.values) {
				foreach (var version in family.versions.values)
					disambiguate_editions (version.editions.values);

				finalize_base_editions (family);
			}
		}

		private OsFamily build_family_for_media (Osinfo.Os os, Osinfo.Media media) {
			var family = OsMapper.family_from_osinfo (os, "");

			var version_id = os.version ?? "unknown";
			var version = OsMapper.version_from_osinfo (version_id, os);
			family.versions.set (version_id, version);

			var edition_id = OsParser.get_edition_id (os, media);
			var edition = OsMapper.edition_from_osinfo (os, media);
			version.editions.set (edition_id, edition);

			edition.images.add (OsMapper.image_from_osinfo (os, media));

			if (media.architecture != null)
				arches.add (media.architecture);

			return family;
		}

		private OsFamily? build_family (Osinfo.Os os, string primary_distro) {
			var family = OsMapper.family_from_osinfo (os, primary_distro);

			var version_id = os.version ?? "unknown";
			OsVersion? version = null;

			foreach (var entity in os.get_media_list ().get_elements ()) {
				var media = (Osinfo.Media) entity;
				if (media.url == null)
					continue;

				if (version == null) {
					version = family.versions.get (version_id);

					if (version == null) {
						version = OsMapper.version_from_osinfo (version_id, os);
						family.versions.set (version_id, version);
					}
				}

				var edition_id = OsParser.get_edition_id (os, media);
				var edition = version.editions.get (edition_id);
				if (edition == null) {
					edition = OsMapper.edition_from_osinfo (os, media);
					version.editions.set (edition_id, edition);
				}

				edition.images.add (OsMapper.image_from_osinfo (os, media));

				if (media.architecture != null)
					arches.add (media.architecture);
			}

			return family.versions.is_empty ? null : family;
		}

		private void disambiguate_editions (Gee.Collection<OsEdition> editions) {
			var by_name = new Gee.HashMap<string, Gee.ArrayList<OsEdition>> ();
			foreach (var edition in editions) {
				if (!by_name.has_key (edition.name))
					by_name.set (edition.name, new Gee.ArrayList<OsEdition> ());

				by_name.get (edition.name).add (edition);
			}

			foreach (var group in by_name.values) {
				if (group.size < 2)
					continue;

				foreach (var edition in group) {
					var token = OsParser.find_install_method_token (edition);

					if (token != "") {
						edition.name = "%s %s".printf (
							edition.name,
							OsParser.humanize_id (token)
						);
					} else if (!OsParser.id_redundant_with_name (edition.id, edition.name)) {
						edition.name = "%s %s".printf (
							edition.name,
							OsParser.humanize_id (edition.id)
						);
					}
				}
			}
		}

		private void finalize_base_editions (OsFamily family) {
			var only_base = true;

			foreach (var version in family.versions.values) {
				foreach (var id in version.editions.keys) {
					if (id != OsParser.BASE_EDITION_ID) {
						only_base = false;
						break;
					}
				}

				if (!only_base)
					break;
			}

			if (!only_base)
				return;

			foreach (var version in family.versions.values) {
				var base_edition = version.editions.get (OsParser.BASE_EDITION_ID);

				if (base_edition != null)
					base_edition.name = family.name;
			}
		}

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
