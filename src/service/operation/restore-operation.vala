/* restore-operation.vala
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

	public class RestoreOperation : Operation {

		private IDeviceHandle device_handle;

		public signal void completed ();

		public RestoreOperation (
			IDeviceHandle device_handle,
			Cancellable cancellable
		) {
			this.device_handle = device_handle;
			this.cancellable = cancellable;
		}

		public override async void run_async () throws Error {
			state = State.PREPARING;
			try {
				yield device_handle.unmount (cancellable);

				state = State.WRITING;
				yield device_handle.format ("vfat", cancellable);
			} catch (Error e) {
				if (!(e is IOError.CANCELLED) && !device_handle.is_auth_dismissed (e))
					failed (_("%s: %s").printf (state_label (state), e.message));

				return;
			}

			completed ();
		}
	}
}
