/* primary-os-row.vala
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

	[GtkTemplate (ui = "/org/altlinux/Tailor/download-page-row.ui")]
	public class DownloadPageRow : Adw.ActionRow {

		public bool is_primary { get; construct; }

		public OsFamily family { get; construct; }
		public OsEdition? edition { get; construct; default = null; }

		public DownloadPageRow.primary (OsFamily family, OsEdition edition) {
			Object (is_primary: true, family: family, edition: edition);
		}

		public DownloadPageRow.other (OsFamily family) {
			Object (is_primary: false, family: family);
		}

		construct {
			title = is_primary && edition != null
				? @"$(family.name) $(edition.name)"
				: family.name;

			subtitle = family.vendor;
		}
	}
}
