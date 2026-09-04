/* main.vala — FlashHelper.exe
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

void* disk_handle = null;
string? locked_device_path = null;
FileStream? log_file = null;

int main (string[] args) {
	log_file = FileStream.open (own_directory () + "\\tailor-flash-helper.log", "w");

	if (args.length < 2) {
		log ("usage: FlashHelper.exe <pipe-name>");
		return 1;
	}

	var pipe_name = args[1];

	if (!Win32.wait_named_pipe (pipe_name, 5000)) {
		log ("WaitNamedPipe failed, GetLastError=%u".printf (Win32.get_last_error ()));
		return 1;
	}

	var pipe_handle = Win32.create_file (
		pipe_name,
		Win32.GENERIC_READ | Win32.GENERIC_WRITE,
		0,
		null,
		Win32.OPEN_EXISTING,
		0,
		null
	);

	if (pipe_handle == Win32.invalid_handle_value) {
		log ("CreateFile(pipe) failed, GetLastError=%u".printf (Win32.get_last_error ()));
		return 1;
	}

	run_loop (pipe_handle);

	if (disk_handle != null && disk_handle != Win32.invalid_handle_value)
		Win32.close_handle (disk_handle);

	Win32.close_handle (pipe_handle);

	return 0;
}

void run_loop (void* pipe_handle) {
	while (true) {
		uint8 tag;
		uint8[] payload;

		try {
			Tailor.FlashPipe.read_frame (pipe_handle, out tag, out payload);
		} catch (Error e) {
			log ("read_frame failed: %s".printf (e.message));
			return;
		}

		if (tag == Tailor.FlashPipe.TAG_CLOSE)
			return;

		if (tag == Tailor.FlashPipe.TAG_LOCK) {
			handle_lock (pipe_handle, Tailor.FlashPipe.payload_to_string (payload));
		} else if (tag == Tailor.FlashPipe.TAG_WRITE) {
			handle_write (pipe_handle, payload);
		} else if (tag == Tailor.FlashPipe.TAG_VERIFY) {
			handle_verify (pipe_handle, payload);
		} else if (tag == Tailor.FlashPipe.TAG_FORMAT) {
			handle_format (pipe_handle, Tailor.FlashPipe.payload_to_string (payload));
		} else {
			send_error (pipe_handle, "not implemented yet");
		}
	}
}

void handle_lock (void* pipe_handle, string device_path) {
	locked_device_path = device_path;

	disk_handle = Win32.create_file (
		device_path,
		Win32.GENERIC_READ | Win32.GENERIC_WRITE,
		0,
		null,
		Win32.OPEN_EXISTING,
		0,
		null
	);

	if (disk_handle == Win32.invalid_handle_value) {
		send_error (pipe_handle, "CreateFile(%s) failed, GetLastError=%u".printf (device_path, Win32.get_last_error ()));
		return;
	}

	uint32 bytes_returned;
	var updated = Win32.device_io_control (
		disk_handle, Win32.IOCTL_DISK_UPDATE_PROPERTIES, null, 0, null, 0, out bytes_returned, null
	);

	if (!updated)
		log ("handle_lock: IOCTL_DISK_UPDATE_PROPERTIES failed, GetLastError=%u".printf (Win32.get_last_error ()));

	send_ok (pipe_handle);
}

void handle_write (void* pipe_handle, uint8[] chunk) {
	if (disk_handle == null || disk_handle == Win32.invalid_handle_value) {
		send_error (pipe_handle, "WRITE received before a successful LOCK");
		return;
	}

	uint8* base_ptr = (uint8*) chunk;
	uint32 written = 0;

	while (written < chunk.length) {
		uint32 chunk_written;
		uint32 remaining = (uint32) chunk.length - written;

		if (!Win32.write_file (disk_handle, base_ptr + written, remaining, out chunk_written, null)) {
			send_error (pipe_handle, "WriteFile(disk) failed, GetLastError=%u".printf (Win32.get_last_error ()));
			return;
		}

		if (chunk_written == 0) {
			send_error (pipe_handle, "WriteFile(disk) wrote 0 bytes");
			return;
		}

		written += chunk_written;
	}

	send_ok (pipe_handle);
}

void handle_verify (void* pipe_handle, uint8[] payload) {
	if (disk_handle == null || disk_handle == Win32.invalid_handle_value) {
		send_error (pipe_handle, "VERIFY received before a successful LOCK");
		return;
	}

	if (payload.length < 8) {
		send_error (pipe_handle, "VERIFY payload too short");
		return;
	}

	int64 total_bytes = 0;
	for (int i = 0; i < 8; i++)
		total_bytes |= ((int64) payload[i]) << (i * 8);

	Win32.LargeInteger zero_offset = { 0 };

	if (!Win32.set_file_pointer (disk_handle, zero_offset, null, Win32.FILE_BEGIN)) {
		send_error (pipe_handle, "SetFilePointerEx failed, GetLastError=%u".printf (Win32.get_last_error ()));
		return;
	}

	var buf = new uint8[1024 * 1024];
	uint8* base_ptr = (uint8*) buf;
	int64 remaining = total_bytes;

	while (remaining > 0) {
		uint32 to_read = (uint32) int64.min (remaining, buf.length);
		uint32 bytes_read;

		if (!Win32.read_file (disk_handle, base_ptr, to_read, out bytes_read, null)) {
			send_error (pipe_handle, "ReadFile(disk) failed, GetLastError=%u".printf (Win32.get_last_error ()));
			return;
		}

		if (bytes_read == 0) {
			send_error (pipe_handle, "ReadFile(disk) hit unexpected EOF during VERIFY");
			return;
		}

		var chunk = buf[0:bytes_read];

		try {
			Tailor.FlashPipe.write_frame (pipe_handle, Tailor.FlashPipe.TAG_DATA, chunk);
		} catch (Error e) {
			log ("VERIFY DATA write_frame failed: %s".printf (e.message));
			return;
		}

		remaining -= bytes_read;
	}

	send_ok (pipe_handle);
}

void handle_format (void* pipe_handle, string fstype) {
	if (locked_device_path == null) {
		send_error (pipe_handle, "FORMAT received before a successful LOCK");
		return;
	}

	var disk_number = parse_disk_number (locked_device_path);
	if (disk_number < 0) {
		send_error (pipe_handle, "could not parse disk number from %s".printf (locked_device_path));
		return;
	}

	if (disk_handle != null && disk_handle != Win32.invalid_handle_value) {
		Win32.close_handle (disk_handle);
		disk_handle = null;
	}

	var diskpart_fs = fstype == "vfat" ? "fat32" : fstype;

	var script_path = own_directory () + "\\tailor-diskpart.txt";
	var script = "select disk %d\nattributes disk clear readonly\nclean\ncreate partition primary\nformat fs=%s quick\nassign\n".printf (
		disk_number, diskpart_fs
	);

	var script_file = FileStream.open (script_path, "w");
	if (script_file == null) {
		send_error (pipe_handle, "could not write diskpart script to %s".printf (script_path));
		return;
	}
	script_file.printf ("%s", script);
	script_file = null; // closes the file

	var output_path = own_directory () + "\\tailor-diskpart-output.txt";
	var command_line = "cmd.exe /c diskpart /s \"%s\" > \"%s\" 2>&1".printf (script_path, output_path);

	Win32.StartupInfo si = {};
	si.cb = (uint32) sizeof (Win32.StartupInfo);

	Win32.ProcessInformation pi = {};

	if (!Win32.create_process (null, command_line, null, null, false, 0, null, null, &si, &pi)) {
		send_error (pipe_handle, "CreateProcess(diskpart) failed, GetLastError=%u".printf (Win32.get_last_error ()));
		return;
	}

	Win32.wait_for_single_object (pi.process, 120000);

	uint32 exit_code;
	var got_exit_code = Win32.get_exit_code_process (pi.process, out exit_code);
	Win32.close_handle (pi.process);
	Win32.close_handle (pi.thread);

	if (!got_exit_code || exit_code != 0) {
		send_error (pipe_handle, "diskpart exited with code %u: %s".printf (exit_code, read_diskpart_output (output_path)));
		return;
	}

	send_ok (pipe_handle);
}

int parse_disk_number (string device_path) {
	int end = device_path.length;
	int start = end;

	while (start > 0 && device_path[start - 1].isdigit ())
		start--;

	if (start == end)
		return -1;

	return int.parse (device_path.substring (start));
}

void send_ok (void* pipe_handle) {
	try {
		Tailor.FlashPipe.write_frame (pipe_handle, Tailor.FlashPipe.TAG_OK, new uint8[0]);
	} catch (Error e) {
		log ("send_ok failed: %s".printf (e.message));
	}
}

void send_error (void* pipe_handle, string message) {
	try {
		Tailor.FlashPipe.write_frame (pipe_handle, Tailor.FlashPipe.TAG_ERROR, message.data);
	} catch (Error e) {
		log ("send_error failed: %s".printf (e.message));
	}
}

string read_diskpart_output (string path) {
	string contents;

	try {
		FileUtils.get_contents (path, out contents);
	} catch (Error e) {
		return "(could not read diskpart output: %s)".printf (e.message);
	}

	return contents.strip ();
}

string own_directory () {
	var buffer = new uint8[260];
	Win32.get_module_file_name (null, buffer, buffer.length);

	var own_path = (string) buffer;

	var last_slash = own_path.last_index_of ("\\");
	return last_slash >= 0 ? own_path.substring (0, last_slash) : ".";
}

void log (string message) {
	if (log_file == null)
		return;

	log_file.printf ("%s\n", message);
	log_file.flush ();
}
