/* usb-repository.vala
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

	public class UsbRepository {

		private UDisks.Client client;

		public signal void device_added (UsbDevice device);
		public signal void device_removed (string object_path);

		public async void init_async () throws Error {
			client = yield new UDisks.Client (null);
			var manager = client.get_object_manager ();

			manager.object_added.connect (on_object_added);
			manager.object_removed.connect (on_object_removed);

			foreach (var obj in manager.get_objects ())
				on_object_added (obj);
		}

		private void on_object_added (DBusObject obj) {
			var device = make_device (obj);
			if (device != null) device_added (device);
		}

		private void on_object_removed (DBusObject obj) {
			device_removed (obj.get_object_path ());
		}

		private UsbDevice? make_device (DBusObject dbus_obj) {
			var udisks_obj = (UDisks.Object) dbus_obj;
			var block = udisks_obj.get_block ();

			if (block == null) return null;

			var drive_obj = (UDisks.Object?) client.get_object_manager ()
				.get_object (block.drive);
			if (drive_obj == null) return null;

			var drive = drive_obj.get_drive ();
			if (drive == null) return null;

			/* Allow:
			 * top-level block-devices,
			 * USB bus,
			 * removable
			 */
			if (drive.connection_bus != "usb") return null;
			if (!drive.removable) return null;
			if (drive.size == 0) return null;
			if (block.hint_system) return null;
			if (block.hint_ignore) return null;

			// Ignore partition objects
			if (block.size != drive.size) return null;

			var object_info = client.get_object_info (udisks_obj);
			var icon = object_info.get_icon_symbolic ();
			var media_icon = object_info.get_media_icon_symbolic ();

			var device = new UsbDevice (udisks_obj.get_object_path ());

			device.device_file = block.device;
			device.name = object_info.get_name ();
			device.description = object_info.get_media_description ();
			device.size = drive.size;
			device.size_display = client.get_size_for_display (drive.size, false, false);
			device.icon = media_icon != null ? media_icon : icon;

			return device;
		}
	}
}
