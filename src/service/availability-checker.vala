/* availability-checker.vala
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

	public class AvailabilityChecker : Object {

		private Soup.Session session = new Soup.Session ();

		construct {
			session.timeout = 3;
		}

		public async bool is_url_available (string url) {
			var msg = new Soup.Message ("HEAD", url);
			try {
				yield session.send_async (msg, Priority.DEFAULT, null);

				return msg.status_code / 100 == 2 || msg.status_code / 100 == 3;
			} catch {
				return false;
			}
		}
	}
}
