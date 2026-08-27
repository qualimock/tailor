/* parsing.vala
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

	public class OsParser {

		public const string BASE_EDITION_ID = "__base__";

		private const string[,] FAMILY_ALIASES = {
			{ "opensusetumbleweed", "opensuse" },
			{ "altlinux", "alt" },
		};

		private const string[] FAMILY_SUFFIXES = {
			"testing", "unstable", "stable",
			"rolling", "rawhide", "unknown",
			"factory", "tumbleweed", "latest",
			"beta", "nightly",
		};

		private const string[,] ACRONYMS = {
			{ "dvd", "DVD" },
			{ "cd", "CD" },
			{ "iso", "ISO" },
			{ "kde", "KDE" },
			{ "xfce", "Xfce" },
			{ "gnome", "GNOME" },
			{ "lxde", "LXDE" },
			{ "lxqt", "LXQt" },
			{ "mate", "MATE" },
			{ "netinst", "Netinst" },
			{ "ftp", "FTP" },
			{ "http", "HTTP" },
			{ "nfs", "NFS" },
			{ "dev", "Dev" },
			{ "ltsb", "LTSB" },
			{ "ltsc", "LTSC" },
			{ "lts", "LTS" },
			{ "eval", "Eval" },
			{ "x86", "x86" },
			{ "x64", "x64" },
		};

		private const string[] INSTALL_METHOD_TOKENS = {
			"netinst", "dvd", "boot", "minimal", "live",
			"everything", "cloud", "atomic", "ostree"
		};

		private static Gee.HashMap<string, string>? _acronyms = null;
		private static Gee.HashMap<string, string>? _family_aliases = null;

		public static string family_id_from_short_id (string short_id) {
			try {
				// almalinux9 -> almalinux, fedora33 -> fedora
				var re = new Regex ("""^(.*?)[0-9.]*$""");
				MatchInfo m;

				if (re.match (short_id, 0, out m)) {
					var id = m.fetch (1);
					if (id != null && id != "")
						return id;
				}
			} catch (RegexError e) {
				warning ("Regex error: %s", e.message);
			}

			return short_id;
		}

		public static string normalize_family_id (string raw_id) {
			var id = raw_id;

			foreach (var suffix in FAMILY_SUFFIXES) {
				if (id.has_suffix (suffix) && id != suffix) {
					id = id.substring (0, id.length - suffix.length);
					break;
				}
			}

			var aliases = family_aliases ();
			return aliases.has_key (id) ? aliases.get (id) : id;
		}

		public static string get_family_name (Osinfo.Os os) {
			var name = os.name;
			for (int i = 0; i < name.length - 1; i++) {
				if (name[i] == ' ' && name[i + 1].isdigit ())
					return name[0:i];
			}

			int last_space = name.last_index_of (" ");
			if (last_space >= 0) {
				var last_word = name[last_space + 1:].down ();

				foreach (var word in FAMILY_SUFFIXES) {
					if (word in last_word)
						return name[0:last_space].strip ();
				}
			}

			return name.strip ();
		}

		public static string get_edition_id (Osinfo.Os os, Osinfo.Media media) {
			var variants = media.get_os_variants ().get_elements ();

			if (variants.is_empty ())
				return BASE_EDITION_ID;

			return ((Osinfo.OsVariant) variants.nth_data (0)).id;
		}

		public static string get_edition_name (Osinfo.Os os, Osinfo.Media media) {
			var variants = media.get_os_variants ().get_elements ();

			if (variants.is_empty ())
				return os.name ?? get_family_name (os);

			var variant = (Osinfo.OsVariant) variants.nth_data (0);
			var name = derive_display_name (variant.name ?? "", os.name ?? "", os.short_id);

			if (name == "")
				name = humanize_id (get_edition_id (os, media));

			return name;
		}

		public static string humanize_id (string id) {
			var acr = acronyms ();
			var parts = id.split ("-");
			var builder = new StringBuilder ();

			foreach (var p in parts) {
				if (builder.len > 0)
					builder.append (" ");

				var lower = p.down ();

				if (acr.has_key (lower))
					builder.append (acr.get (lower));
				else
					builder.append (p.up (1) + p.substring (1));
			}

			return builder.str;
		}

		public static string find_install_method_token (OsEdition edition) {
			var id = edition.id.down ();

			foreach (var token in INSTALL_METHOD_TOKENS) {
				if (id.contains (token))
					return token;
			}

			foreach (var image in edition.images) {
				var url = image.url.down ();

				foreach (var token in INSTALL_METHOD_TOKENS) {
					if (url.contains (token))
						return token;
				}
			}

			return "";
		}

		public static bool id_redundant_with_name (string id, string name) {
			var sid = squash (id);
			var sname = squash (name);

			return sname.contains (sid) || sid.contains (sname);
		}

		private static string squash (string s) {
			return s.down ().replace (" ", "").replace ("-", "");
		}

		// Remove all except edition from <variant><name>, e.g. "Fedora Server 42" -> "Server"
		private static string derive_display_name (string variant_name, string os_name, string short_id) {
			var result = variant_name;

			var word_tokens = new Gee.ArrayList<string> ();
			foreach (var token in os_name.split (" ")) {
				if (token == "" || is_number (token))
					continue;

				word_tokens.add (token);
			}

			var ascii_key = family_id_from_short_id (short_id);
			if (ascii_key != "" && !word_tokens.contains (ascii_key))
				word_tokens.add (ascii_key);

			result = remove_squashed_product_name (result, word_tokens);

			foreach (var token in word_tokens)
				result = remove_whole_word (result, token);

			try {
				// ALT Workstation 11.1 -> ALT Workstation
				var re = new Regex ("""\b[0-9]+(\.[0-9]+)*\b""");
				result = re.replace (result, result.length, 0, "");

				// Merge whitespace
				var ws = new Regex ("""\s+""");
				result = ws.replace (result, result.length, 0, " ").strip ();
			} catch (RegexError e) {}

			result = strip_wrapping_parens (result);

			return result;
		}

		private static bool is_number (string token) {
			try {
				var re = new Regex ("""^[0-9]+(\.[0-9]+)*$""");
				return re.match (token);
			} catch (RegexError e) {
				return false;
			}
		}

		private static string remove_squashed_product_name (string text, Gee.ArrayList<string> tokens) {
			if (tokens.size == 0)
				return text;

			var parts = new string[tokens.size];

			for (int i = 0; i < tokens.size; i++)
				parts[i] = Regex.escape_string (tokens.get (i));

			var pattern = string.joinv ("\\s*", parts);

			try {
				var re = new Regex (pattern, RegexCompileFlags.CASELESS);
				MatchInfo mi;
				if (re.match (text, 0, out mi)) {
					int start, end;
					mi.fetch_pos (0, out start, out end);
					return text.substring (0, start) + text.substring (end);
				}
			} catch (RegexError e) {
				warning ("Regex error: %s", e.message);
			}

			return text;
		}

		private static string remove_whole_word (string text, string word) {
			if (word == "")
				return text;

			try {
				var re = new Regex (
					"""\b""" + Regex.escape_string (word) + """\b""",
					RegexCompileFlags.CASELESS
				);

				return re.replace (text, text.length, 0, "");
			} catch (RegexError e) {
				return text;
			}
		}

		private static string strip_wrapping_parens (string text) {
			var t = text.strip ();

			if (t.has_prefix ("(") && t.has_suffix (")"))
				return t.substring (1, t.length - 2).strip ();

			return t;
		}

		private static Gee.HashMap<string, string> family_aliases () {
			if (_family_aliases == null) {
				_family_aliases = new Gee.HashMap<string, string> ();

				for (int i = 0; i < FAMILY_ALIASES.length[0]; i++)
					_family_aliases.set (FAMILY_ALIASES[i, 0], FAMILY_ALIASES[i, 1]);
			}

			return _family_aliases;
		}

		private static Gee.HashMap<string, string> acronyms () {
			if (_acronyms == null) {
				_acronyms = new Gee.HashMap<string, string> ();

				for (int i = 0; i < ACRONYMS.length[0]; i++)
					_acronyms.set (ACRONYMS[i, 0], ACRONYMS[i, 1]);
			}

			return _acronyms;
		}
	}
}
