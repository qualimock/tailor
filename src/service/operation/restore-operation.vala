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

	public class RestoreOperation : DeviceOperation {

		public signal void completed ();

		public RestoreOperation (
			UDisks.Block block,
			DBusObjectManager object_manager,
			Cancellable cancellable
		) {
			init_device (block, object_manager, cancellable);
		}

		public override async void run_async () throws Error {
			try {
				yield unmount ();
				yield block.call_format ("vfat", new Variant ("a{sv}", null), cancellable);
			} catch (Error e) {
				if (is_auth_dismissed (e))
					throw new IOError.CANCELLED (e.message);

				if (!(e is IOError.CANCELLED))
					failed (_("%s: %s").printf (state_label (state), e.message));

				throw e;
			}

			completed ();
		}
	}
}
