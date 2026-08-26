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
		private OsImage? selected_image = null;
		private File? image_file;
		private Cancellable cancellable;
		private bool trash_after_flashing = false;
		private StatusLine[] flash_steps;
		private FlashOperation? operation = null;
		private string? last_error_message = null;
		private uint pulse_timeout_id = 0;

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
		public bool started { get; private set; default = false; }
		public bool flashing { get; private set; default = false; }
		public bool success { get; private set; default = false; }
		public bool finished { get; private set; default = false; }
		public bool cancelled { get; private set; default = false; }
		public bool paused { get; private set; default = false; }
		public bool has_checksum { get; set; default = false; }

		static construct {
			typeof (StatusLine).ensure ();
			typeof (ProgressLine).ensure ();
		}

		public void configure_from_image (File image, UsbDevice device) {
			reset ();

			this.device = device;
			selected_image = null;
			image_file = image;

			build_flash_steps ();

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

		public void configure_from_os (
			OsFamily family,
			OsEdition? edition,
			OsVersion? version,
			OsImage image,
			UsbDevice selected_device,
			bool trash_download
		) {
			reset ();

			device = selected_device;
			trash_after_flashing = trash_download;
			selected_image = image;

			build_flash_steps ();

			os_statuspage.title = "%s %s %s %s".printf (
				family.name,
				edition?.name ?? "",
				version?.version ?? "",
				version?.codename != null ? @"($(version.codename))" : ""
			).strip ();

			os_statuspage.description = family.vendor;
			os_statuspage.icon_name = ""; // TODO: add OS icons
			os_statuspage.badge = image.arch;
			os_statuspage.badge_visible = true;

			download_status.title = _("Downloading image %s").printf (Path.get_basename (image.url));
			download_status.visible = true;
		}

		private void build_flash_steps () {
			flash_steps = {};

			if (selected_image != null) {
				flash_steps += download_status;

				if (selected_image.checksum != null)
					flash_steps += checksum_status;
			}

			flash_steps += prepare_status;
			flash_steps += write_status;
			flash_steps += verify_status;
		}

		private void reset () {
			started = false;
			flashing = false;
			finished = false;
			success = false;
			cancelled = false;
			paused = false;
			has_checksum = false;

			stop_pulse ();
			progress_bar.fraction = 0;

			cancellable = null;
			operation = null;
			last_error_message = null;

			download_status.state = StatusState.PENDING;
			checksum_status.state = StatusState.PENDING;
			prepare_status.state = StatusState.PENDING;
			write_status.state = StatusState.PENDING;
			verify_status.state = StatusState.PENDING;

			set_progress_css_class ("accent");
			progress_status.title = _("Starting");
		}

		private void flash () {
			has_checksum = selected_image?.checksum != null;
			cancellable = new Cancellable ();

			try {
				if (selected_image == null) {
					operation = service.usb.create_flash_operation_with_file (
						device, image_file, cancellable
					);
				} else {
					operation = service.usb.create_flash_operation_with_download (
						device, selected_image, cancellable
					);
				}
			} catch (Error e) {
				on_failed (e.message);
				return;
			}

			operation.progress.connect (on_progress);
			operation.downloaded.connect ((file, skipped) => {
				image_file = file;
				if (skipped) {
					download_status.state = StatusState.SKIPPED;
					service.ui.toast_requested (new Adw.Toast (_("Image is already downloaded")));
				}
			});
			operation.completed.connect (on_completed);
			operation.failed.connect (on_failed);
			operation.notify["state"].connect (on_operation_state_changed);

			operation.run_async.begin ((obj, res) => {
				try {
					operation.run_async.end (res);
				} catch (IOError.CANCELLED e) {
					if (!finished)
						on_cancel ();
				} catch (Error e) {}
			});
		}

		private void on_progress (int64 written, int64 total) {
			if (total > 0) {
				stop_pulse ();
				progress_bar.fraction = (double) written / total;
				progress_status.title = operation.title;
			} else {
				start_pulse ();
			}
		}

		private void start_pulse () {
			if (pulse_timeout_id != 0)
				return;

			progress_status.title = _("Trying to reconnect");
			pulse_timeout_id = Timeout.add (100, () => {
				progress_bar.pulse ();
				return Source.CONTINUE;
			});
		}

		private void stop_pulse () {
			if (pulse_timeout_id != 0) {
				Source.remove (pulse_timeout_id);
				pulse_timeout_id = 0;
			}
		}

		private void activate_flash_step (StatusLine target) {
			var reached = false;
			foreach (var step in flash_steps) {
				if (step == target) {
					step.state = StatusState.ACTIVE;
					reached = true;
					continue;
				}

				if (reached) {
					step.state = StatusState.PENDING;
				} else if (step.state != StatusState.SKIPPED) {
					step.state = StatusState.FINISHED;
				}
			}
		}

		private StatusLine? terminate_current_flash_step (StatusState terminal) {
			foreach (var step in flash_steps) {
				if (step.state == StatusState.ACTIVE || step.state == StatusState.PAUSED) {
					step.state = terminal;
					return step;
				}
			}

			return null;
		}

		private string step_failure_label (StatusLine? step) {
			if (step == download_status)
				return _("Downloading the image failed");
			if (step == checksum_status)
				return _("Checksum verification failed");
			if (step == prepare_status)
				return _("Preparing the device failed");
			if (step == write_status)
				return _("Writing the image failed");
			if (step == verify_status)
				return _("Verifying the write failed");

			return _("An error occurred during writing process");
		}

		private void on_operation_state_changed () {
			switch (operation.state) {
			case Operation.State.DOWNLOADING:
				operation.title = _("Downloading");
				activate_flash_step (download_status);
				break;

			case Operation.State.CHECKSUM:
				operation.title = _("Verifying checksum");
				activate_flash_step (checksum_status);
				break;

			case Operation.State.PREPARING:
				operation.title = _("Preparing device");
				activate_flash_step (prepare_status);
				break;

			case Operation.State.WRITING:
				operation.title = _("Writing image");
				activate_flash_step (write_status);
				flashing = true;
				break;

			case Operation.State.VERIFYING:
				operation.title = _("Verifying installation");
				activate_flash_step (verify_status);
				break;

			case Operation.State.PAUSED:
				progress_status.title = _("Paused");
				terminate_current_flash_step (StatusState.PAUSED);
				return;
			}

			progress_status.title = operation.title;
		}

		private void on_completed () {
			finished = true;
			success = true;
			started = false;
			flashing = false;

			stop_pulse ();
			terminate_current_flash_step (StatusState.FINISHED);

			set_progress_css_class ("success");
			flash_result_label.label = _("The image was written successfully");

			if (trash_after_flashing && image_file != null)
				image_file.delete_async.begin (Priority.DEFAULT, null, null);

			if (selected_image != null)
				image_file = null;
		}

		private void on_failed (string message) {
			if (finished)
				return;

			finished = true;
			success = false;
			started = false;
			flashing = false;

			stop_pulse ();
			var failed_step = terminate_current_flash_step (StatusState.FAILED);

			set_progress_css_class ("error");

			last_error_message = message;
			flash_result_label.label = step_failure_label (failed_step);

			if (selected_image != null && image_file != null) {
				image_file.delete_async.begin (Priority.DEFAULT, null, null);
				image_file = null;
			}
		}

		private void on_cancel () {
			finished = true;
			success = false;
			cancelled = true;
			started = false;
			flashing = false;

			stop_pulse ();
			terminate_current_flash_step (StatusState.ABORTED);

			set_progress_css_class ("warning");
			flash_result_label.label = _("Writing was canceled");

			if (trash_after_flashing && image_file != null) {
				image_file.delete_async.begin (Priority.DEFAULT, null, null);
				image_file = null;
			}
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

		[GtkCallback]
		private string fraction_to_string (double value) {
			return "%.0f".printf (value * 100);
		}

		[GtkCallback]
		private string get_paused_label (bool is_paused) {
			return is_paused ? _("Resume") : _("Pause");
		}

		[GtkCallback]
		private bool logical_and (bool a, bool b) {
			return a && b;
		}

		[GtkCallback]
		private bool logical_not (bool a) {
			return !a;
		}

		[GtkCallback]
		private void start_flashing () {
			if (started)
				return;

			reset ();

			started = true;
			flash ();
		}

		[GtkCallback]
		private void cancel_flashing () {
			if (cancellable == null)
				return;

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
			} else {
				if (selected_image != null && !trash_after_flashing) {
					dialog.body = "%s\n%s".printf (
						dialog.body,
						_("Downloaded image will not be deleted.")
					);
				}
			}

			if (!paused)
				toggle_pause ();

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
				operation?.pause ();
				set_progress_css_class ("dimmed");
			} else {
				operation?.resume ();
				set_progress_css_class ("accent");
			}
		}

		[GtkCallback]
		private void show_error_details () {
			service.ui.show_details (this, _("Error Details"), last_error_message);
		}
	}
}
