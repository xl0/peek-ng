using Peek;

void test_make_even () {
  assert(Utils.make_even (3) == 2);
  assert(Utils.make_even (4) == 4);
  assert(Utils.make_even (0) == 0);
  assert(Utils.make_even (-7) == -6);
  assert(Utils.make_even (-12) == -12);
}

void test_command_output () {
  var loop = new MainLoop ();
  try {
    var process = new Subprocess.newv ({
      "sh", "-c",
      "head -c 2097152 /dev/zero | tr '\\000' x; " +
      "printf '\\rprogress\\n\\377final diagnostic\\n' >&2; exit 7"
    }, SubprocessFlags.STDOUT_PIPE | SubprocessFlags.STDERR_MERGE);
    uint timeout = Timeout.add_seconds (5, () => {
      process.force_exit ();
      error ("Timed out draining command output");
    });
    Utils.wait_with_output_async.begin (process, (obj, res) => {
      try {
        string output = Utils.wait_with_output_async.end (res);
        assert (process.get_exit_status () == 7);
        assert (output.validate ());
        // Replacing the invalid byte with U+FFFD adds two bytes.
        assert (output.length == 65538);
        assert (output.has_suffix ("\rprogress\n�final diagnostic\n"));
      } catch (Error e) {
        error ("%s", e.message);
      }
      Source.remove (timeout);
      loop.quit ();
    });
  } catch (Error e) {
    error ("%s", e.message);
  }
  loop.run ();
}

void main (string[] args) {
  Test.init (ref args);

  Test.add_func ("/utils/test_make_even", test_make_even);
  Test.add_func ("/utils/command_output", test_command_output);

  Test.run ();
}
