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

		private Gee.HashSet<string> known_paths = new Gee.HashSet<string> ();

		public signal void device_added (UsbDevice device);
		public signal void device_removed (string object_path);
		public signal void device_updated (UsbDevice device);

		public async void init_async () throws Error {
			client = yield new UDisks.Client (null);
			var manager = client.get_object_manager ();

			manager.object_added.connect (on_object_added);
			manager.object_removed.connect (on_object_removed);
			client.changed.connect (on_client_changed);

			foreach (var obj in manager.get_objects ())
				on_object_added (obj);
		}

		private void on_object_added (DBusObject obj) {
			var device = make_device (obj);

			if (device != null) {
				known_paths.add (device.object_path);
				device_added (device);
			}

			maybe_update_parent (obj);
		}

		private void on_object_removed (DBusObject obj) {
			var path = obj.get_object_path ();

			if (known_paths.remove (path))
				device_removed (path);

			maybe_update_parent (obj);
		}

		private void on_client_changed () {
			foreach (var path in known_paths) {
				var obj = client.get_object_manager ().get_object (path);
				if (obj == null)
					continue;

				var updated = make_device (obj);
				if (updated == null)
					continue;

				device_updated (updated);
			}
		}

		private void maybe_update_parent (DBusObject obj) {
			var udisks_obj = obj as UDisks.Object;
			if (udisks_obj == null)
				return;

			var partition = udisks_obj.get_partition ();
			if (partition == null || partition.is_container)
				return;

			var parent_path = partition.table;
			if (!known_paths.contains (parent_path))
				return;

			var parent_obj = client.get_object_manager ().get_object (parent_path);
			if (parent_obj == null)
				return;

			var updated = make_device (parent_obj);
			if (updated == null)
				return;

			device_updated (updated);
		}

		private string get_device_display_size (string total_space, uint64 used_bytes) {
			var used_space = used_bytes != 0 ? client.get_size_for_display (used_bytes, false, false) : null;
			if (used_space == null)
				return total_space;

			var used_parts = used_space.split (" ");
			var total_parts = total_space.split (" ");

			if (used_parts.length >= 2 && total_parts.length >= 2)
				if (used_parts[1] == total_parts[1])
					return @"$(used_parts[0])/$(total_space)";

			return @"$(used_space)/$(total_space)";
		}

		private uint64 count_drive_used_bytes (DBusObject drive, string drive_path) {
			var udisks_obj = drive as UDisks.Object;
			if (udisks_obj == null)
				return 0;

			var block = udisks_obj.get_block ();
			if (block == null) return 0;
			if (block.drive != drive_path) return 0;
			if (block.size == 0) return 0;

			var fs = udisks_obj.get_filesystem ();
			if (fs == null || fs.mount_points.length == 0)
				return 0;

			Posix.statvfs stat_buf;
			if (Posix.statvfs_exec (fs.mount_points[0], out stat_buf) != 0)
				return 0;

			return (stat_buf.f_blocks - stat_buf.f_bfree) * stat_buf.f_frsize;
		}

		private bool is_partition (DBusObject obj, string object_path) {
			var udisks_obj = obj as UDisks.Object;
			if (udisks_obj == null)
				return false;

			var partition = udisks_obj.get_partition ();
			if (partition == null)
				return false;

			// Filter to this drive only
			if (partition.table != object_path)
				return false;

			if (partition.is_container)
				return false;

			return true;
		}

		private UsbDevice? make_device (DBusObject dbus_obj) {
			var udisks_obj = dbus_obj as UDisks.Object;
			if (udisks_obj == null) return null;

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

			var device = new UsbDevice (udisks_obj.get_object_path ());
			device.device_file = block.device;
			device.name = object_info.get_name ();
			device.size = drive.size;

			uint64 used_bytes = 0;
			uint partition_count = 0;
			foreach (var obj in client.get_object_manager ().get_objects ()) {
				used_bytes += count_drive_used_bytes (obj, drive_obj.get_object_path ());

				if (is_partition (obj, udisks_obj.get_object_path ()))
					partition_count++;
			}

			device.size_display = get_device_display_size (
				client.get_size_for_display (drive.size, false, false),
				used_bytes
			);

			if (partition_count > 0) {
				device.filesystem = ngettext ("%u partition", "%u partitions", partition_count)
					.printf (partition_count);
			} else {
				device.filesystem = (block.id_type != null && block.id_type != "")
					? block.id_type
					: _("No filesystem");
			}

			return device;
		}
	}
}
