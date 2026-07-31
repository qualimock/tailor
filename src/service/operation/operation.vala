/* operation.vala
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

	public abstract class Operation : Object {

		public enum State {
			PAUSED,
			DOWNLOADING,
			CHECKSUM,
			PREPARING,
			WRITING,
			VERIFYING
		}

		protected Cancellable cancellable;
		protected SourceFunc? resume_func = null;

		protected int64 bytes_written = 0;
		protected int64 total_bytes = 0;

		protected bool paused = false;

		protected State last_state;

		public string title { get; set; }
		public State state { get; protected set; }

		public signal void progress (int64 bytes_written, int64 total);
		public signal void failed (string message);

		public abstract async void run_async () throws Error;

		public virtual void pause () {
			paused = true;
			last_state = state;
			state = State.PAUSED;
		}

		public virtual void resume () {
			paused = false;
			state = last_state;

			if (resume_func != null) {
				var func = (owned) resume_func;
				resume_func = null;
				func ();
			}
		}

		protected string state_label (State state) {
			switch (state) {
			case State.DOWNLOADING: return _("Download");
			case State.CHECKSUM: return _("Checksum verification");
			case State.PREPARING: return _("Device preparation");
			case State.WRITING: return _("Writing");
			case State.VERIFYING: return _("Verification");
			default:
				return _("Flashing");
			}
		}

		protected async void wait_for_resume () {
			resume_func = wait_for_resume.callback;
			yield;
		}
	}
}
