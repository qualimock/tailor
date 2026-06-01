/* status-line.vala
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

	public enum StatusState {
		NONE,
		PENDING,
		ACTIVE,
		FINISHED,
		FAILED,
		ABORTED
	}

	[GtkTemplate (ui = "/org/altlinux/Tailor/status-line.ui")]
	public class StatusLine : Gtk.Box {

		public string title { get; set; default = ""; }
		public string status { get; protected set; }
		public StatusState state { get; set; default = StatusState.PENDING; }

		construct {
			status = status_from_state ();
		}

		private string status_from_state () {
			switch (state) {
				case StatusState.PENDING: return _("Pending");
				case StatusState.ACTIVE: return _("In progress");
				case StatusState.FINISHED: return _("Finished");
				case StatusState.FAILED: return _("Failed");
				case StatusState.ABORTED: return _("Aborted");

				case StatusState.NONE:
				default: return "";
			}
		}

		[GtkCallback]
		private void state_to_status () {
			status = status_from_state ();
		}
	}
}
