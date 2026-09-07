/*
Peek Copyright (c) 2015-2018 by Philipp Wolfer <ph.wolfer@gmail.com>

This file is part of Peek.

This software is licensed under the GNU General Public License
(version 3 or later). See the LICENSE file in this distribution.
*/

namespace Peek {

  public class Utils {
    public static string get_temp_dir () {
      string cache_dir_path = Path.build_filename (
        Environment.get_user_cache_dir (), "peek"
      );
      var cache_dir = File.new_for_path (cache_dir_path);

      try {
        cache_dir.make_directory_with_parents (null);
      } catch (Error e) {
        if (e is IOError.EXISTS) {
          debug ("Cache directory does already exist %s\n", cache_dir_path);
        } else {
          stderr.printf ("Error: %s\n", e.message);
          return Environment.get_tmp_dir ();
        }
      }

      return cache_dir.get_path ();
    }

    public static string create_temp_file (string extension) throws FileError {
      var temp_dir = get_temp_dir ();
      var file_name = Path.build_filename (temp_dir, "peekXXXXXX." + extension);
      var fd = FileUtils.mkstemp (file_name);
      FileUtils.close (fd);
      debug ("Temp file: %s\n", file_name);
      return file_name;
    }

    public static bool is_exit_status_success (int status) {
      try {
        if (Process.check_exit_status (status)) {
          return true;
        }
      }
      catch (Error e) {
        stderr.printf ("Error: %s\n", e.message);
      }

      return false;
    }

    public static bool check_for_executable (string executable) {
      var path = Environment.find_program_in_path (executable);
      return path != null;
    }

    public static string get_file_extension_for_format (OutputFormat output_format) {
      return output_format.to_string ();
    }

    public static int make_even (int i) {
      return (i / 2) * 2;
    }

    public static string get_command_failed_message (
      string[] argv, Subprocess? subprocess = null, string? output = null) {
      int status = -1;
      int term_sig = 0;

      if (subprocess != null) {
        status = subprocess.get_status ();
        if (subprocess.get_if_signaled ()) {
          term_sig = subprocess.get_term_sig ();
        }
      }

      string message = "Command \"%s\" failed with status %i (received signal %i).".printf (
        string.joinv (" ", argv), status, term_sig);

      if (output != null) {
        message += "\n\nOutput:\n%s".printf (output);
      }

      return message;
    }

    /**
    * Drain merged stdout/stderr while the command runs, leaving stdin open
    * for recorder stop commands. Keep only the last 64 KiB for error reports.
    */
    public static async string wait_with_output_async (Subprocess subprocess) throws Error {
      var output = new StringBuilder ();
      var stream = subprocess.get_stdout_pipe ();
      try {
        while (true) {
          // Read bytes, not lines: FFmpeg progress uses carriage returns.
          var bytes = yield stream.read_bytes_async (8192);
          if (bytes.get_size () == 0) {
            break;
          }
          output.append_len ((string) bytes.get_data (), (ssize_t) bytes.get_size ());
          if (output.len > 65536) {
            output.erase (0, (ssize_t) output.len - 65536);
          }
        }
      } catch (Error e) {
        // Without a reader the child could block forever writing its output.
        subprocess.force_exit ();
        yield subprocess.wait_async ();
        throw e;
      }

      yield subprocess.wait_async ();
      return output.str.make_valid ();
    }

    private const string NUMBER_FORMAT = "%02" + int64.FORMAT_MODIFIER + "d";
    private const string TIME_FORMAT = NUMBER_FORMAT + ":" + NUMBER_FORMAT;
    public static string format_time (int64 seconds) {
      return TIME_FORMAT.printf (seconds / 60, seconds % 60);
    }
  }

}
