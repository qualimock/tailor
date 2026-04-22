/* app.vala
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

	public class Application : Adw.Application {

		private MainWindow main_window;

		public Application () {
			Object (application_id: Tailor.ID,
			        resource_base_path: "/org/altlinux/Tailor");
		}

		public override void activate () {
			if (main_window != null) {
				main_window.present ();
				return;
			}

			main_window = new MainWindow (this);

			main_window.present ();
		}
	}
}
