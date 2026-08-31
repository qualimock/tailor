/* device-card.vala
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

	[GtkTemplate (ui = "/org/altlinux/Tailor/device-card.ui")]
	public class DeviceCard : Gtk.Box {

		RestoreOperation operation;
		Cancellable cancellable;

		public bool restoring { get; set; default = false; }
		public bool disks_available { get; set; default = false; }
		public UsbDevice device { get; set; }
		public ServiceContext service { get; set; }

		construct {
			// "Open in Disks" only supported for native installs, launching
			// GNOME Disks from inside the sandbox needs flatpak-spawn --host
			disks_available = !FileUtils.test ("/.flatpak-info", FileTest.EXISTS)
				&& Environment.find_program_in_path ("gnome-disks") != null;
		}

		[GtkCallback]
		private string string_if (bool cond, string if_true, string if_false) {
			return cond ? if_true : if_false;
		}

		[GtkCallback]
		private void on_more_in_disks_clicked () {
			try {
				new Subprocess.newv ({
					"gnome-disks", "--block-device", device.device_file
				}, SubprocessFlags.NONE);
			} catch (Error e) {
				warning ("Failed to open GNOME Disks: %s", e.message);
			}
		}

		[GtkCallback]
		private void on_restore_clicked () {
			if (restoring)
				return;

			string dialog_body = device.has_image
				? _("This will erase the image on %s.").printf (device.name)
				: _("%s contains a regular filesystem. "
				  + "Make sure this is the right device and "
				  + "back up any important data before continuing.").printf (device.name);

			var dialog = new Adw.AlertDialog (_("Restore device?"), dialog_body);
			dialog.add_response ("cancel", _("Cancel"));
			dialog.add_response ("proceed", _("Proceed"));

			dialog.set_default_response ("cancel");
			dialog.set_close_response ("cancel");
			dialog.set_response_appearance ("proceed", Adw.ResponseAppearance.DESTRUCTIVE);

			dialog.response["proceed"].connect (() => {
				restoring = true;
				cancellable = new Cancellable ();

				try {
					operation = service.usb.create_restore_operation (device, cancellable);
				} catch (Error e) {
					var message = e.message;
					restoring = false;

					var toast = new Adw.Toast (_("Failed to restore device"));
					toast.button_label = _("Details");
					toast.button_clicked.connect (() => {
						service.ui.show_details (this, _("Error Details"), message);
					});

					service.ui.toast_requested (toast);
					return;
				}

				operation.completed.connect (() => {
					restoring = false;
					service.ui.toast_requested (new Adw.Toast (_("Device restored")));
				});

				operation.failed.connect ((message) => {
					restoring = false;

					var toast = new Adw.Toast (_("Failed to restore device"));
					toast.button_label = _("Details");
					toast.button_clicked.connect (() => {
						service.ui.show_details (this, _("Error Details"), message);
					});

					service.ui.toast_requested (toast);
				});

				operation.run_async.begin ((obj, res) => {
					try {
						operation.run_async.end (res);
					} catch (Error e) {
						var message = e.message;
						restoring = false;

						var toast = new Adw.Toast (_("Failed to restore device"));
						toast.button_label = _("Details");
						toast.button_clicked.connect (() => {
							service.ui.show_details (this, _("Error Details"), message);
						});

						service.ui.toast_requested (toast);
					}
				});
			});

			dialog.present (this);
		}
	}
}
