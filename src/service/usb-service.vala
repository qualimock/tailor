/* usb-service.vala
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

	public class UsbService {

		private UsbRepository repo;

		public signal void device_added (UsbDevice device);
		public signal void device_removed (string object_path);
		public signal void device_updated (UsbDevice device);

		private void on_device_added (UsbDevice d) { device_added (d); }
		private void on_device_removed (string path) { device_removed (path); }
		private void on_device_updated (UsbDevice device) { device_updated (device); }

		public async void init_async () throws Error {
			repo = new UsbRepository ();

			repo.device_added.connect (on_device_added);
			repo.device_removed.connect (on_device_removed);
			repo.device_updated.connect (on_device_updated);

			yield repo.init_async ();
		}
	}
}
