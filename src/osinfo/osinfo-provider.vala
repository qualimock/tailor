/* osinfo-provider.vala
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

	public class OsinfoProvider {

		private Osinfo.Loader loader = new Osinfo.Loader ();
		private Osinfo.Db db;

		public async void load () throws Error {
			SourceFunc callback = load.callback;
			Error? thread_error = null;

			new Thread<void> ("osinfo-loader", () => {
				try {
					loader.process_default_path ();
					db = loader.get_db ();
				} catch (Error e) {
					thread_error = e;
				}

				Idle.add ((owned) callback);
			});

			yield;

			if (thread_error != null)
				throw thread_error;
		}

		public Gee.ArrayList<Osinfo.Os> get_os_list () {
			var list = new Gee.ArrayList<Osinfo.Os> ();

			foreach (var element in db.get_os_list ().get_elements ()) {
				list.add ((Osinfo.Os) element);
			}

			return list;
		}
	}
}
