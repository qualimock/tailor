/* service-context.vala
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

	public class ServiceContext : Object {

		public OsinfoService osinfo { get; construct; }
		public UsbService usb { get; construct; }
		public UiService ui { get; construct; }
		public string host_arch { get; construct; }
		public File image_file { get; set; }

		public ServiceContext (
			OsinfoService osinfo_service,
			UsbService usb_service,
			UiService ui_service
		) {
			Object (
				osinfo: osinfo_service,
				usb: usb_service,
				ui: ui_service,
				host_arch: resolve_host_arch ()
			);
		}

		private static string resolve_host_arch () {
#if WINDOWS
			Win32.SystemInfo info;
			Win32.get_native_system_info (out info);

			switch (info.processor_architecture) {
			case Win32.PROCESSOR_ARCHITECTURE_AMD64:
				return "x86_64";
			case Win32.PROCESSOR_ARCHITECTURE_ARM64:
				return "aarch64";
			case Win32.PROCESSOR_ARCHITECTURE_ARM:
				return "armv7l";
			case Win32.PROCESSOR_ARCHITECTURE_INTEL:
				return "i686";
			default:
				return "unknown";
			}
#else
			return Posix.utsname ().machine;
#endif
		}
	}
}
