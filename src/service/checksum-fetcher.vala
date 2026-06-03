/* checksum-fetcher.vala
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

	public struct ChecksumResult {
		public string hash;
		public ChecksumType type;
	}

	public class ChecksumFetcher : Object {

		private Soup.Session session = new Soup.Session ();

		construct {
			session.timeout = 10;
			session.user_agent = @"$(Tailor.ID)/$(Tailor.VERSION)";
		}

		public async ChecksumResult? fetch_async (string iso_url, Cancellable? cancellable) {
			var filename = iso_url.substring (iso_url.last_index_of ("/") + 1);
			var candidates = ChecksumResolver.candidates_for (iso_url);

			foreach (var url in candidates) {
				var result = yield try_candidate (session, url, filename, cancellable);

				if (result != null)
					return result;
			}

			return null;
		}

		private async ChecksumResult? try_candidate (
			Soup.Session session,
			string url,
			string filename,
			Cancellable? cancellable
		) {
			try {
				var msg = new Soup.Message ("GET", url);
				var input = yield session.send_async (msg, Priority.DEFAULT, cancellable);

				if (msg.status_code != Soup.Status.OK)
					return null;

				var bytes = yield input.read_bytes_async (1024 * 1024	, Priority.DEFAULT, cancellable);
				var content = (string) bytes.get_data ();

				return parse (content, filename);
			} catch {
				return null;
			}
		}

		private ChecksumResult? parse (string content, string filename) {
			var lines = content.split ("\n");
			var non_empty = 0;

			foreach (var line in lines) {
				if (line.strip () != "")
					non_empty++;
			}

			try {
				foreach (var line in lines) {
					var trimmed = line.strip ();
					if (trimmed == "")
						continue;

					MatchInfo match;

					// BSD style: SHA256 (filename) = hash
					var re = new Regex ("""^[A-Z0-9]+\s+\((.+)\)\s+=\s+([0-9a-f]+)$""");
					if (re.match (trimmed, 0, out match)) {
						if (match.fetch (1) != filename)
							continue;

						return make_result (match.fetch (2));
					}

					// sha256sum style: hash  filename or hash *filename
					re = new Regex ("""^([0-9a-f]+)\s+\*?(.+)$""");
					if (re.match (trimmed, 0, out match)) {
						if (match.fetch (2) != filename)
							continue;

						return make_result (match.fetch (1));
					}

					// bare hash: .sha256 file
					if (non_empty == 1) {
						re = new Regex ("""^([0-9a-f]+)$""");
						if (re.match (trimmed, 0, out match))
							return make_result (match.fetch (1));
					}
				}
			} catch (RegexError e) {
				critical ("Regex error: %s", e.message);
			}

			return null;
		}

		private ChecksumResult? make_result (string hash) {
			ChecksumType type;

			switch (hash.length) {
			case 32: type = ChecksumType.MD5; break;
			case 64: type = ChecksumType.SHA256; break;
			case 128: type = ChecksumType.SHA512; break;
			default: return null;
			}

			return { hash, type };
		}
	}
}
