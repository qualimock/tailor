/* usb-mapper.vala
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

	public class UsbMapper {

		private struct DriveStats {
			uint64 used_bytes;
			uint partition_count;
		}

		public static UsbDevice? from_udisks (DBusObject dbus_obj, UDisks.Client client) {
			var udisks_obj = dbus_obj as UDisks.Object;
			if (udisks_obj == null)
				return null;

			var block = udisks_obj.get_block ();
			if (block == null)
				return null;

			var drive_obj = (UDisks.Object?) client.get_object_manager ().get_object (block.drive);
			if (drive_obj == null)
				return null;

			var drive = drive_obj.get_drive ();
			if (drive == null)
				return null;

			if (!is_valid_drive (drive) || !is_eligible_block (block, drive))
				return null;

			var object_info = client.get_object_info (udisks_obj);
			var dto = new UsbDevice (udisks_obj.get_object_path ());
			dto.device_file = block.device;
			dto.name = object_info.get_name ();
			dto.size = drive.size;

			var stats = get_drive_stats (
				client,
				udisks_obj.get_object_path (),
				drive_obj.get_object_path ()
			);

			dto.filesystem = get_filesystem_label (block, stats.partition_count);

			var total_space = client.get_size_for_display (drive.size, false, false);
			var used_space = stats.used_bytes != 0
				? client.get_size_for_display (stats.used_bytes, false, false)
				: null;

			dto.size_display = get_drive_display_size (total_space, used_space);

			return dto;
		}

		private static bool is_valid_drive (UDisks.Drive drive) {
			return drive.connection_bus == "usb" &&
			       drive.removable &&
			       drive.size != 0;
		}

		private static bool is_eligible_block (UDisks.Block block, UDisks.Drive drive) {
			return !block.hint_system &&
			       !block.hint_ignore &&
			        block.size == drive.size;
		}

		private static DriveStats get_drive_stats (UDisks.Client client,
		                                           string udisks_obj_path,
		                                           string drive_obj_path) {
			uint64 used_bytes = 0;
			uint partition_count = 0;
			foreach (var obj in client.get_object_manager ().get_objects ()) {
				used_bytes += get_drive_used_bytes (obj, drive_obj_path);

				if (is_partition (obj, udisks_obj_path))
					partition_count++;
			}

			return { used_bytes, partition_count };
		}

		private static uint64 get_drive_used_bytes (DBusObject drive, string drive_path) {
			var udisks_obj = drive as UDisks.Object;
			if (udisks_obj == null)
				return 0;

			var block = udisks_obj.get_block ();
			if (block == null)
				return 0;

			if (block.drive != drive_path)
				return 0;

			if (block.size == 0)
				return 0;

			var fs = udisks_obj.get_filesystem ();
			if (fs == null || fs.mount_points.length == 0)
				return 0;

			Posix.statvfs stat_buf;
			if (Posix.statvfs_exec (fs.mount_points[0], out stat_buf) != 0)
				return 0;

			return (stat_buf.f_blocks - stat_buf.f_bfree) * stat_buf.f_frsize;
		}

		private static bool is_partition (DBusObject obj, string object_path) {
			var udisks_obj = obj as UDisks.Object;
			if (udisks_obj == null)
				return false;

			var partition = udisks_obj.get_partition ();
			if (partition == null)
				return false;

			if (partition.table != object_path)
				return false;

			if (partition.is_container)
				return false;

			return true;
		}

		private static string get_filesystem_label (UDisks.Block block, uint partitions) {
			if (partitions > 0)
				return ngettext ("%u partition", "%u partitions", partitions)
					.printf (partitions);

			return (block.id_type != null && block.id_type != "")
				? block.id_type
				: _("No filesystem");
		}

		private static string get_drive_display_size (string total_space, string? used_space) {
			if (used_space == null)
				return total_space;

			var used_parts = used_space.split (" ");
			var total_parts = total_space.split (" ");

			if (used_parts.length < 2 || total_parts.length < 2)
				return @"$(used_space)/$(total_space)";

			if (used_parts[1] != total_parts[1])
				return @"$(used_space)/$(total_space)";

			return @"$(used_parts[0])/$(total_space)";
		}
	}
}
