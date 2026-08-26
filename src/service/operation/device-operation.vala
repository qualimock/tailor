/* device-operation.vala
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

	public abstract class DeviceOperation : Operation {

		protected UDisks.Block block;
		protected DBusObjectManager object_manager;

		protected void init_device (
			UDisks.Block block,
			DBusObjectManager object_manager,
			Cancellable cancellable
		) {
			this.block = block;
			this.object_manager = object_manager;
			this.cancellable = cancellable;
		}

		protected async void unmount () throws Error {
			state = State.PREPARING;

			foreach (var obj in object_manager.get_objects ()) {
				var udisks_obj = obj as UDisks.Object;
				if (udisks_obj == null)
					continue;

				var blk = udisks_obj.block;
				if (blk == null || blk.drive != block.drive)
					continue;

				var filesystem = udisks_obj.filesystem;
				if (filesystem == null || filesystem.mount_points.length == 0)
					continue;

				yield filesystem.call_unmount (new Variant ("a{sv}", null), cancellable);
			}
		}

		protected static bool is_auth_dismissed (Error e) {
			return e.message.contains ("NotAuthorizedDismissed");
		}
	}
}
