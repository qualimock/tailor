/* flash-pipe.vala
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

namespace Tailor.FlashPipe {

	public const uint8 TAG_LOCK = 'L';
	public const uint8 TAG_WRITE = 'W';
	public const uint8 TAG_VERIFY = 'V';
	public const uint8 TAG_FORMAT = 'F';
	public const uint8 TAG_CLOSE = 'C';
	public const uint8 TAG_PROGRESS = 'P';
	public const uint8 TAG_DATA = 'D';
	public const uint8 TAG_OK = 'O';
	public const uint8 TAG_ERROR = 'E';

	public string payload_to_string (uint8[] payload) {
		var buf = new uint8[payload.length + 1];

		for (int i = 0; i < payload.length; i++)
			buf[i] = payload[i];

		return (string) buf;
	}

	public errordomain PipeError {
		CLOSED,
		IO
	}

	// Frame: 1-byte tag + 4-byte little-endian length + payload
	public void write_frame (void* pipe_handle, uint8 tag, uint8[] payload) throws PipeError {
		var header = new uint8[5];
		header[0] = tag;
		header[1] = (uint8) (payload.length & 0xFF);
		header[2] = (uint8) ((payload.length >> 8) & 0xFF);
		header[3] = (uint8) ((payload.length >> 16) & 0xFF);
		header[4] = (uint8) ((payload.length >> 24) & 0xFF);

		write_exact (pipe_handle, header);

		if (payload.length > 0)
			write_exact (pipe_handle, payload);
	}

	public void read_frame (void* pipe_handle, out uint8 tag, out uint8[] payload) throws PipeError {
		var header = read_exact (pipe_handle, 5);

		tag = header[0];

		uint32 length = header[1]
			| (((uint32) header[2]) << 8)
			| (((uint32) header[3]) << 16)
			| (((uint32) header[4]) << 24);

		payload = length > 0 ? read_exact (pipe_handle, length) : new uint8[0];
	}

	private void write_exact (void* pipe_handle, uint8[] data) throws PipeError {
		uint8* base_ptr = (uint8*) data;
		uint32 written = 0;

		while (written < data.length) {
			uint32 chunk_written;
			uint32 remaining_length = (uint32) data.length - written;

			if (!Win32.write_file (pipe_handle, base_ptr + written, remaining_length, out chunk_written, null))
				throw new PipeError.IO ("WriteFile failed, GetLastError=%u".printf (Win32.get_last_error ()));

			if (chunk_written == 0)
				throw new PipeError.CLOSED ("pipe closed mid-write");

			written += chunk_written;
		}
	}

	private uint8[] read_exact (void* pipe_handle, uint32 count) throws PipeError {
		var buf = new uint8[count];
		uint8* base_ptr = (uint8*) buf;
		uint32 total_read = 0;

		while (total_read < count) {
			uint32 chunk_read;
			uint32 remaining_length = count - total_read;

			if (!Win32.read_file (pipe_handle, base_ptr + total_read, remaining_length, out chunk_read, null))
				throw new PipeError.IO ("ReadFile failed, GetLastError=%u".printf (Win32.get_last_error ()));

			if (chunk_read == 0)
				throw new PipeError.CLOSED ("pipe closed mid-read");

			total_read += chunk_read;
		}

		return buf;
	}
}
