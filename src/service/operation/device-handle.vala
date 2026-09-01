/* device-handle.vala
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

	public interface IDeviceHandle : Object {

		public signal void progress (int64 written, int64 total);

		public abstract async void unmount (
			Cancellable cancellable
		) throws Error;

		public abstract async Checksum write (
			InputStream source,
			int64 total_bytes,
			IPauseGate pause_gate,
			Cancellable cancellable
		) throws Error;

		public abstract async void verify (
			Checksum expected,
			int64 total_bytes,
			Cancellable cancellable
		) throws Error;

		public abstract async void format (
			string fstype,
			Cancellable cancellable
		) throws Error;

		public abstract bool is_auth_dismissed (Error e);
	}
}
