/* usb-provider-linux.vala
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

	public class UsbProviderLinux : Object, IUsbProvider {

		private UDisks.Client client;

		public async void init_async () throws Error {
			client = yield new UDisks.Client (null);
			var manager = client.get_object_manager ();

			manager.object_added.connect (on_object_added);
			manager.object_removed.connect (on_object_removed);
			client.changed.connect (on_client_changed);

			foreach (var obj in manager.get_objects ())
				on_object_added (obj);
		}

		public IDeviceHandle get_device_handle (UsbDevice device) throws Error {
			var udisks_obj = client.get_object (device.object_path);
			if (udisks_obj == null)
				throw new IOError.NOT_FOUND ("Device not found: %s", device.object_path);

			var block = udisks_obj.get_block ();
			if (block == null)
				throw new IOError.NOT_FOUND ("No block interface for: %s", device.object_path);

			return new DeviceHandleLinux (
				block,
				client.get_object_manager ()
			);
		}

		private void on_object_added (DBusObject object) {
			var device = UsbMapper.from_udisks (object, client);

			if (device != null)
				device_added (device);

			var parent_path = get_parent_path (object);
			if (parent_path != null)
				emit_updated_for_path (parent_path);
		}

		private void on_object_removed (DBusObject object) {
			var path = object.get_object_path ();
			var parent_path = get_parent_path (object);

			device_removed (path);

			if (parent_path != null)
				emit_updated_for_path (parent_path);
		}

		private void on_client_changed () {
			foreach (var obj in client.get_object_manager ().get_objects ())
				emit_updated_for_path (obj.get_object_path ());
		}

		private string? get_parent_path (DBusObject object) {
			var udisks_obj = object as UDisks.Object;
			if (udisks_obj == null)
				return null;

			var partition = udisks_obj.get_partition ();
			if (partition == null || partition.is_container)
				return null;

			return partition.table;
		}

		private void emit_updated_for_path (string path) {
			var obj = client.get_object_manager ().get_object (path);
			if (obj == null)
				return;

			var updated = UsbMapper.from_udisks (obj, client);
			if (updated == null)
				return;

			device_updated (updated);
		}
	}
}
