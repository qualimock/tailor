/* os-image.vala
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

	public class OsImage : Object {

		private ChecksumFetcher checksum_fetcher = new ChecksumFetcher ();
		private AvailabilityChecker checker = new AvailabilityChecker ();
		private ChecksumType checksum_type = ChecksumType.SHA256;

		public string? arch { get; set; default = null; }
		public string url { get; set; }
		public OsResources resources { get; set; }

		public int64 volume_size { get; set; default = -1; }
		public string? media_type { get; set; default = null; }
		public string? checksum { get; private set; default = null; }

		public async void fetch_checksum (Cancellable? cancellable = null) {
			if (url == null)
				return;

			var result = yield checksum_fetcher.fetch_async (url, cancellable);

			if (result == null)
				return;

			checksum_type = result.type;
			checksum = result.hash;
		}

		public async bool verify_checksum (File file, Cancellable? cancellable = null) throws Error {
			if (checksum == null)
				return true;

			var chsum = new Checksum (checksum_type);
			var stream = yield file.read_async (Priority.DEFAULT, cancellable);
			var buf = new uint8[65536];
			ssize_t n;

			while ((n = yield stream.read_async (buf, Priority.DEFAULT, cancellable)) > 0)
				chsum.update (buf[0:n], n);

			yield stream.close_async (Priority.DEFAULT, cancellable);

			return chsum.get_string () == checksum;
		}

		public async bool check_downloadable () {
			return yield checker.is_url_available (url);
		}
	}
}
