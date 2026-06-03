/* checksum-resolver.vala
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

	namespace ChecksumResolver {

		public string[] candidates_for (string iso_url) {
			Uri uri = null;
			try {
				uri = Uri.parse (iso_url, UriFlags.NONE);
			} catch (UriError e) {
				critical ("Failed to parse URL: %s", iso_url);
				return {};
			}

			var host = uri.get_host ();
			var path = uri.get_path ();
			var dir = path.substring (0, path.last_index_of ("/") + 1);
			var file = path.substring (path.last_index_of ("/") + 1);
			var base_url = @"https://$host$dir";

			if ("fedoraproject.org" in host)
				return fedora_candidates (base_url, file);

			if ("openbsd.org" in host || "ftp.lysator.liu.se" in host)
				return { base_url + "SHA256" };

			if ("netbsd.org" in host)
				return { base_url + "SHA512" };

			if ("alpinelinux.org" in host ||
			    "nixos.org" in host ||
			    "endlessm.com" in host ||
			    "opensuse.org" in host)
				return { iso_url + ".sha256" };

			return {
				base_url + "SHA256SUMS",
				base_url + "SHA256SUM",
				base_url + "SHA512SUMS",
				base_url + "SHA512SUM",
				base_url + "MD5SUMS",
				base_url + "MD5SUM"
			};
		}

		private string[] fedora_candidates (string base_url, string filename) {
			try {
				// Workstation-style: product-Variant-version.build.arch.iso
				var re = new Regex ("""^(Fedora-\w+)-(?:Live|dvd|netinst|boot)-(\d+)-([\d.]+)\.(\w+)\.iso$""");
				MatchInfo match;

				if (re.match (filename, 0, out match)) {
					return { base_url + "%s-%s-%s-%s-CHECKSUM".printf (
						match.fetch (1), match.fetch (2), match.fetch (3), match.fetch (4)
					)};
				}

				// Server-style: product-variant-arch-version-build.iso
				re = new Regex ("""^(Fedora-\w+)-(?:dvd|netinst|boot)-(\w+)-(\d+)-([\d.]+)\.iso$""");
				if (re.match (filename, 0, out match)) {
					return { base_url + "%s-%s-%s-%s-CHECKSUM".printf (
						match.fetch (1), match.fetch (3), match.fetch (4), match.fetch (2)
					)};
				}
			} catch (RegexError e) {
				critical ("Regex error: %s", e.message);
			}

			// Unknown
			return {};
		}
	}
}
