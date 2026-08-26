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
		public UsbDevice device { get; set; }
		public ServiceContext service { get; set; }

		private async void open_in_disks () {
			try {
				if (FileUtils.test ("/.flatpak-info", FileTest.EXISTS)) {
					yield open_in_disks_from_flatpak ();
				} else {
					yield open_in_disks_native ();
				}
			} catch (Error e) {
				warning ("Failed to open gnome-disks: %s", e.message);
			}
		}

		private async void open_in_disks_native () throws Error {
			try {
				new Subprocess.newv ({
						"gnome-disks", "--block-device", device.device_file
					},
					SubprocessFlags.NONE
				);
			} catch (Error e) {
				new Subprocess.newv ({
						"flatpak", "run",
						"org.gnome.DiskUtility", "--block-device", device.device_file
					},
					SubprocessFlags.NONE
				);
			}
		}

		private async void open_in_disks_from_flatpak () throws Error {
			var probe = new Subprocess.newv ({
					"flatpak-spawn", "--host",
					"sh", "-c", "command -v gnome-disks"
				},
				SubprocessFlags.NONE
			);
			yield probe.wait_async (null);

			string[] cmd;
			if (probe.get_exit_status () == 0) {
				cmd = {
					"flatpak-spawn", "--host",
					"gnome-disks", "--block-device", device.device_file
				};
			} else {
				cmd = {
					"flatpak-spawn", "--host",
					"flatpak", "run", "org.gnome.DiskUtility", "--block-device", device.device_file
				};
			}
			new Subprocess.newv (cmd, SubprocessFlags.NONE);
		}

		[GtkCallback]
		private string string_if (bool cond, string if_true, string if_false) {
			return cond ? if_true : if_false;
		}

		[GtkCallback]
		private void on_more_in_disks_clicked () {
			open_in_disks.begin ();
		}

		[GtkCallback]
		private void on_restore_clicked () {
			if (restoring)
				return;

			var dialog = new Adw.AlertDialog (
				_("Restore device?"),
				_("All data on %s will be erased!").printf (device.name)
			);
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
