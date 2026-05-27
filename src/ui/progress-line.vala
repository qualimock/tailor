/* progress-line.vala
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

	[GtkTemplate (ui = "/org/altlinux/Tailor/progress-line.ui")]
	public class ProgressLine : StatusLine {
		private string _progress;

		public string progress {
			get { return _progress; }
			set {
				if (!is_valid (value)) {
					critical ("Value should be between 0 and 100, current: %s", value);
					return;
				}

				_progress = @"$value%";
			}
		}

		private bool is_valid (string input) {
			var s = input.strip ();

			int value;
			unowned string rest;
			if (!int.try_parse (s, out value, out rest, 10))
				return false;

			if (rest != "")
				return false;

			return value >= 0 && value <= 100;
		}
	}
}
