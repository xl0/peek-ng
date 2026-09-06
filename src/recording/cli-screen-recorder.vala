/*
Peek Copyright (c) 2015-2018 by Philipp Wolfer <ph.wolfer@gmail.com>

This file is part of Peek.

This software is licensed under the GNU General Public License
(version 3 or later). See the LICENSE file in this distribution.
*/

using Peek.PostProcessing;

namespace Peek.Recording {

  public abstract class CliScreenRecorder : BaseScreenRecorder {
    protected Subprocess subprocess;
    protected OutputStream input;

    protected void spawn_record_command (string[] argv) throws RecordingError {
      try {
        string[] my_args = argv[0:argv.length];
        subprocess = new Subprocess.newv (argv, SubprocessFlags.STDIN_PIPE | SubprocessFlags.STDOUT_PIPE | SubprocessFlags.STDERR_MERGE);
        input = subprocess.get_stdin_pipe ();
        var process = subprocess;
        Utils.wait_with_output_async.begin (process, (obj, res) => {
          bool success = false;
          int status = 0;
          int term_sig = 0;
          string? output = null;
          try {
            output = Utils.wait_with_output_async.end (res);
            success = process.get_successful ();
            if (process.get_if_exited ()) {
              status = process.get_exit_status ();
            } else if (process.get_if_signaled ()) {
              term_sig = process.get_term_sig ();
            }

            debug ("recording process exited, term_sig: %d, exit_status: %d, success: %s",
              term_sig, status, success.to_string ());
          } catch (Error e) {
            stderr.printf ("Error: %s\n", e.message);
            status = -1;
            success = false;
            output = e.message;
          }

          // A cancelled recording may have been replaced while it was exiting.
          if (subprocess != process) {
            return;
          }
          subprocess = null;
          input = null;

          if (temp_file != null) {
            var file = File.new_for_path (temp_file);
            try {
              var file_info = file.query_info ("*", FileQueryInfoFlags.NONE);
              debug ("Temporary file %s, %" + int64.FORMAT + " bytes",
              temp_file, file_info.get_size ());
            } catch (Error e) {
              stderr.printf ("Error: %s\n", e.message);
            }
          }

          // If the recorder was cancelled no further action is required
          if (is_cancelling) {
            return;
          }

          if (!success) {
            string message = Utils.get_command_failed_message (my_args, process, output);
            var reason = new RecordingError.RECORDING_ABORTED (message);
            recording_aborted (reason);
          } else {
            finalize_recording ();
          }
        });


        is_recording = true;
        recording_started ();
      } catch (Error e) {
        throw new RecordingError.INITIALIZING_RECORDING_FAILED (e.message);
      }
    }

    protected override void stop_recording () {
      if (subprocess != null) {
        subprocess.force_exit ();
      }
    }

    protected virtual bool is_exit_status_success (int status) {
      return Utils.is_exit_status_success (status);
    }
  }

}
