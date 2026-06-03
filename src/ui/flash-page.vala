/* flash-page.vala
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

	[GtkTemplate (ui = "/org/altlinux/Tailor/flash-page.ui")]
	public class FlashPage : Adw.NavigationPage {

		private UsbDevice device;
		private Os? selected_os = null;
		private File? temp_file;
		private bool flashing = false;
		private Cancellable cancellable;
		private bool trash_after_flashing = false;

		private Operation? active_operation = null;

		[GtkChild] private unowned StatusPageWithBadge os_statuspage;

		[GtkChild] private unowned Gtk.ProgressBar progress_bar;
		[GtkChild] private unowned ProgressLine progress_status;
		[GtkChild] private unowned Gtk.Label flash_result_label;

		[GtkChild] private unowned StatusLine download_status;
		[GtkChild] private unowned StatusLine checksum_status;
		[GtkChild] private unowned StatusLine prepare_status;
		[GtkChild] private unowned StatusLine write_status;
		[GtkChild] private unowned StatusLine verify_status;

		public ServiceContext service { get; construct set; }
		public bool success { get; private set; default = false; }
		public bool finished { get; private set; default = false; }
		public bool paused { get; private set; default = false; }
		public bool has_checksum { get; set; default = false; }

		static construct {
			typeof (StatusLine).ensure ();
			typeof (ProgressLine).ensure ();
		}

		public void configure_from_image (File image, UsbDevice device) {
			reset ();

			this.device = device;
			selected_os = null;

			try {
				var info = image.query_info (
					FileAttribute.STANDARD_SIZE, FileQueryInfoFlags.NONE
				);

				os_statuspage.badge = format_size (info.get_size ());
			} catch (Error e) {
				os_statuspage.badge_visible = false;
			}

			os_statuspage.title = "%s".printf (image.get_basename ());
			os_statuspage.description = _("Local file");
			os_statuspage.icon_name = "media-optical-symbolic";
			download_status.visible = false;
		}

		public void configure_from_os (OsFamily family, Os os, UsbDevice selected_device, bool trash_download) {
			reset ();

			device = selected_device;
			trash_after_flashing = trash_download;
			selected_os = os;

			os_statuspage.title = "%s %s %s %s".printf (
				family.display_name,
				os.edition ?? "",
				os.version ?? "",
				os.codename != null ? @"($(os.codename))" : ""
			).strip ();

			os_statuspage.description = family.vendor;
			os_statuspage.icon_name = ""; // TODO: add OS icons
			os_statuspage.badge = os.arch;
			os_statuspage.badge_visible = true;

			download_status.title = _("Downloading image %s").printf (Path.get_basename (os.url));
			download_status.visible = true;
		}

		private void reset () {
			flashing = false;
			finished = false;
			success = false;
			paused = false;
			has_checksum = false;

			progress_bar.fraction = 0;

			active_operation = null;
			temp_file = null;

			download_status.state = StatusState.PENDING;
			checksum_status.state = StatusState.PENDING;
			prepare_status.state = StatusState.PENDING;
			write_status.state = StatusState.PENDING;
			verify_status.state = StatusState.PENDING;

			set_progress_css_class ("accent");
			progress_status.title = _("Starting");
		}

		private void download_and_flash () {
			has_checksum = selected_os?.checksum != null;
			download_status.state = StatusState.ACTIVE;

			var op = new DownloadOperation (selected_os, cancellable);
			active_operation = op;

			op.progress.connect (on_download_progress);
			op.failed.connect (on_failed);
			op.completed.connect (on_downloaded);
			op.notify["state"].connect (on_operation_state_changed);

			op.run_async.begin ((obj, res) => {
				try { op.run_async.end (res); }
				catch (Error e) {}
			});
		}

		private void flash (File image, Cancellable cancellable) {
			FlashOperation op;
			try {
				op = service.usb.create_flash_operation (device, image, cancellable);
				active_operation = op;
			} catch (Error e) {
				on_failed (e.message);
				return;
			}

			op.progress.connect (on_flash_progress);
			op.completed.connect (on_completed);
			op.failed.connect (on_failed);
			op.notify["state"].connect (on_operation_state_changed);

			op.run_async.begin ((obj, res) => {
				try { op.run_async.end (res); }
				catch (Error e) {}
			});
		}

		private void on_downloaded (File tmp_file) {
			download_status.state = StatusState.FINISHED;
			temp_file = tmp_file;

			if (selected_os.checksum != null) {
				checksum_status.state = StatusState.ACTIVE;

				var mismatch_str = _("Checksum mismatch - the download can be corrupted");
				selected_os.verify_checksum.begin (tmp_file, cancellable, (_, res) => {
					try {
						var verified = selected_os.verify_checksum.end (res);

						if (!verified) {
							on_failed (mismatch_str);
							return;
						}
					} catch (Error e) {
						on_failed (e.message);
						return;
					}

					checksum_status.state = StatusState.FINISHED;
					flash (tmp_file, cancellable);
				});
			} else {
				flash (tmp_file, cancellable);
			}
		}

		private void on_download_progress (int64 written, int64 total) {
			progress_status.title = _("Downloading");
			if (total > 0)
				progress_bar.fraction = (double) written / total;
			else
				progress_bar.pulse ();
		}

		private void on_flash_progress (int64 written, int64 total) {
			if (total > 0)
				progress_bar.fraction = (double) written / total;
			else
				progress_bar.pulse ();
		}

		private void on_operation_state_changed () {
			switch (active_operation.state) {
			case Operation.State.PREPARING:
				active_operation.title = _("Preparing device");
				prepare_status.state = StatusState.ACTIVE;
				break;

			case Operation.State.WRITING:
				active_operation.title = _("Writing image");
				prepare_status.state = StatusState.FINISHED;
				write_status.state = StatusState.ACTIVE;
				break;

			case Operation.State.VERIFYING:
				active_operation.title = _("Verifying installation");
				write_status.state = StatusState.FINISHED;
				verify_status.state = StatusState.ACTIVE;
				break;

			case Operation.State.DOWNLOADING:
				download_status.state = StatusState.ACTIVE;
				break;

			case Operation.State.PAUSED:
				progress_status.title = _("Paused");
				set_state_on (StatusState.PAUSED, StatusState.ACTIVE);
				return;
			}

			progress_status.title = active_operation.title;
		}

		private void on_completed () {
			finished = true;
			success = true;

			set_progress_css_class ("success");
			flash_result_label.label = _("The image was written successfully");

			set_state_on (StatusState.FINISHED, StatusState.ACTIVE);

			if (trash_after_flashing && temp_file != null)
				temp_file.delete_async.begin (Priority.DEFAULT, null, null);

			temp_file = null;
		}

		private void on_failed (string message) {
			if (finished)
				return;

			finished = true;
			success = false;
			flashing = false;

			set_progress_css_class ("error");
			flash_result_label.label = _("An error occurred during writing process: %s").printf (message);

			set_state_on (StatusState.FAILED, StatusState.ACTIVE);

			if (temp_file != null)
				temp_file.delete_async.begin (Priority.DEFAULT, null, null);

			temp_file = null;
		}

		private void on_cancel () {
			finished = true;
			success = false;

			set_progress_css_class ("warning");
			flash_result_label.label = _("Writing was canceled");

			set_state_on (StatusState.ABORTED, StatusState.PAUSED);

			if (temp_file != null)
				temp_file.delete_async.begin (Priority.DEFAULT, null, null);

			temp_file = null;
		}

		private void set_progress_css_class (string css_class) {
			reset_css_classes (progress_bar);
			reset_css_classes (flash_result_label);

			progress_bar.add_css_class (css_class);
			flash_result_label.add_css_class (css_class);
		}

		private void reset_css_classes (Gtk.Widget widget) {
			string[] classes = { "accent", "success", "warning", "error", "dimmed" };

			foreach (var css in classes) {
				if (widget.has_css_class (css)) {
					widget.remove_css_class (css);
				}
			}
		}

		private void set_state_on (StatusState state, StatusState current) {
			if (download_status.state == current)
				download_status.state = state;

			if (checksum_status.state == current)
				checksum_status.state = state;

			if (prepare_status.state == current)
				prepare_status.state = state;

			if (write_status.state == current)
				write_status.state = state;

			if (verify_status.state == current)
				verify_status.state = state;
		}

		[GtkCallback]
		private string fraction_to_string (double value) {
			return "%.0f".printf (value * 100);
		}

		[GtkCallback]
		private string get_paused_label (bool is_paused) {
			return is_paused ? _("Resume") : _("Pause");
		}

		[GtkCallback]
		private void start_flashing () {
			if (flashing)
				return;

			reset ();

			flashing = true;
			cancellable = new Cancellable ();

			if (selected_os == null) {
				flash (service.image_file, cancellable);
				return;
			}

			download_and_flash ();
		}

		[GtkCallback]
		private void cancel_flashing () {
			if (cancellable == null)
				return;

			toggle_pause ();

			var dialog = new Adw.AlertDialog (
				_("Cancel tailoring?"),
				_("The device may be left in an incomplete state and fail to boot.")
			);
			dialog.add_response ("continue", _("Continue"));
			dialog.add_response ("cancel", _("Cancel Anyway"));

			dialog.set_default_response ("continue");
			dialog.set_close_response ("continue");
			dialog.set_response_appearance ("cancel", Adw.ResponseAppearance.DESTRUCTIVE);

			if (download_status.state == StatusState.ACTIVE ||
			    checksum_status.state == StatusState.ACTIVE) {
				dialog.heading = _("Cancel download?");
				dialog.body = _("The device won't be affected.");
			}

			dialog.response["cancel"].connect (() => {
				cancellable.cancel ();
				on_cancel ();
			});

			dialog.response["continue"].connect (toggle_pause);

			dialog.present (this);
		}

		[GtkCallback]
		private void toggle_pause () {
			paused = !paused;
			if (paused) {
				active_operation?.pause ();
				set_progress_css_class ("dimmed");
			} else {
				active_operation?.resume ();
				set_progress_css_class ("accent");
			}
		}
	}
}
