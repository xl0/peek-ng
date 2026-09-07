using Peek;
using Peek.Recording;
using Peek.PostProcessing;

// More output than a pipe can hold, including FFmpeg-style CR-only progress.
const string NOISY_COMMAND =
  "head -c 2097152 /dev/zero | tr '\\000' x; " +
  "head -c 2097152 /dev/zero | tr '\\000' y >&2; " +
  "printf '\\rfinal diagnostic\\n' >&2; ";

class NoisyScreenRecorder : FfmpegScreenRecorder {
  public bool fail;

  protected override void start_recording (RecordingArea area) throws RecordingError {
    try {
      config.output_format = OutputFormat.MP4;
      temp_file = Utils.create_temp_file ("mp4");
      string ending = fail ? "exit 7" :
        "test \"$(dd bs=1 count=1 2>/dev/null)\" = q";
      spawn_record_command ({ "sh", "-c", NOISY_COMMAND + ending });
    } catch (FileError e) {
      throw new RecordingError.INITIALIZING_RECORDING_FAILED (e.message);
    }
  }

  public void cleanup () {
    if (subprocess != null) {
      subprocess.force_exit ();
    }
    remove_temp_file ();
  }
}

class NoisyPostProcessor : CliPostProcessor {
  public bool fail;

  public override async Array<File> process_async (Array<File> files) throws RecordingError {
    yield spawn_command_async ({ "sh", "-c",
      NOISY_COMMAND + (fail ? "exit 7" : "exit 0") });
    return files;
  }
}

void test_noisy_recording (bool fail, bool cancel = false) {
  var recorder = new NoisyScreenRecorder ();
  recorder.fail = fail;
  var loop = new MainLoop ();
  bool completed = false;
  bool timed_out = false;
  recorder.recording_finished.connect ((file) => {
    assert (!fail && !cancel);
    FileUtils.remove (file.get_path ());
    completed = true;
    loop.quit ();
  });
  recorder.recording_aborted.connect ((reason) => {
    assert (fail || cancel);
    if (fail) {
      assert (reason != null);
      assert ("final diagnostic" in reason.message);
    } else {
      assert (reason == null);
    }
    completed = true;
    loop.quit ();
  });
  try {
    recorder.record (RecordingArea ());
  } catch (RecordingError e) {
    error ("%s", e.message);
  }
  if (!fail) {
    Timeout.add (1100, () => {
      if (cancel) {
        recorder.cancel ();
      } else {
        recorder.stop ();
      }
      return Source.REMOVE;
    });
  }
  uint timeout = Timeout.add_seconds (5, () => {
    timed_out = true;
    recorder.cleanup ();
    loop.quit ();
    return Source.REMOVE;
  });
  loop.run ();
  if (!timed_out) {
    Source.remove (timeout);
  }
  recorder.cleanup ();
  assert (!timed_out);
  assert (completed);
}

void test_noisy_postprocessing (bool fail) {
  var processor = new NoisyPostProcessor ();
  processor.fail = fail;
  var loop = new MainLoop ();
  bool completed = false;
  bool timed_out = false;
  processor.process_async.begin (new Array<File> (), (obj, res) => {
    try {
      processor.process_async.end (res);
      assert (!fail);
    } catch (RecordingError e) {
      assert (fail);
      assert ("final diagnostic" in e.message);
    }
    completed = true;
    loop.quit ();
  });
  uint timeout = Timeout.add_seconds (5, () => {
    timed_out = true;
    processor.cancel ();
    loop.quit ();
    return Source.REMOVE;
  });
  loop.run ();
  if (!timed_out) {
    Source.remove (timeout);
  }
  assert (!timed_out);
  assert (completed);
}

// Writes a new temp file and returns it, like the real post processors.
class CopyPostProcessor : Object, PostProcessor {
  public async Array<File> process_async (Array<File> files) throws RecordingError {
    try {
      var output = File.new_for_path (Utils.create_temp_file ("out"));
      yield files.index (0).copy_async (output, FileCopyFlags.OVERWRITE);
      var result = new Array<File> ();
      result.append_val (output);
      return result;
    } catch (Error e) {
      throw new RecordingError.POSTPROCESSING_ABORTED (e.message);
    }
  }

  public void cancel () {}
}

// Each step's input must be deleted, its output handed on intact.
void test_pipeline_cleanup () {
  var loop = new MainLoop ();
  try {
    var input = File.new_for_path (Utils.create_temp_file ("in"));
    var pipeline = new PostProcessingPipeline ();
    pipeline.add (new CopyPostProcessor ());
    pipeline.add (new CopyPostProcessor ());
    var files = new Array<File> ();
    files.append_val (input);
    pipeline.process_async.begin (files, (obj, res) => {
      try {
        var output = pipeline.process_async.end (res);
        assert (output.length == 1);
        assert (output.index (0).query_exists ());
        assert (!input.query_exists ());
        FileUtils.remove (output.index (0).get_path ());
      } catch (Error e) {
        error ("%s", e.message);
      }
      loop.quit ();
    });
  } catch (Error e) {
    error ("%s", e.message);
  }
  loop.run ();
}

class TestCliScreenRecorder : CliScreenRecorder {
  public bool stop_command_called { get; set; default = false; }

  public override void start_recording (RecordingArea area) throws RecordingError {
    is_recording = true;
    stop_command_called = false;
  }

  protected override void stop_recording () {
    stop_command_called = true;
  }
}

void test_cancel () {
  var recorder = new TestCliScreenRecorder ();
  bool recording_aborted_called = false;
  recorder.recording_aborted.connect ((reason) => {
    recording_aborted_called = true;
    assert (reason == null);
  });

  try {
    recorder.record (RecordingArea ());
  } catch (RecordingError e) {
    assert (false);
  }

  assert (recorder.is_recording);
  assert (!recorder.stop_command_called);

  recorder.cancel ();

  assert (!recorder.is_recording);
  assert (recorder.stop_command_called);
  assert (recording_aborted_called);
}

void main (string[] args) {
  Test.init (ref args);

  Test.add_func (
    "/screen-recorder/cli-screen-recorder/test_cancel",
    test_cancel);
  Test.add_func ("/screen-recorder/noisy/stop", () => test_noisy_recording (false));
  Test.add_func ("/screen-recorder/noisy/failure", () => test_noisy_recording (true));
  Test.add_func ("/screen-recorder/noisy/cancel", () => test_noisy_recording (false, true));
  Test.add_func ("/post-processing/noisy/success", () => test_noisy_postprocessing (false));
  Test.add_func ("/post-processing/noisy/failure", () => test_noisy_postprocessing (true));
  Test.add_func ("/post-processing/pipeline/cleanup", test_pipeline_cleanup);

  Test.run ();
}
