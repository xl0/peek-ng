/*
Peek Copyright (c) 2017-2018 by Philipp Wolfer <ph.wolfer@gmail.com>

This file is part of Peek.

This software is licensed under the GNU General Public License
(version 3 or later). See the LICENSE file in this distribution.
*/

using Peek.PostProcessing;

namespace Peek.Recording {

  /**
  * Owns the lifecycle of a take. Backends implement start_recording and
  * stop_recording and report back through finalize_recording (the file is
  * complete) or recording_failed (it is not); all state transitions and
  * signals live here.
  */
  public abstract class BaseScreenRecorder : Object, ScreenRecorder {
    protected enum State {
      IDLE,       // nothing running; also after cancel while a backend still exits
      RECORDING,
      STOPPING,   // stop requested, waiting for the backend to finish the file
      PROCESSING  // post-processing pipeline running
    }

    private State _state = State.IDLE;
    protected State state {
      get { return _state; }
    }

    protected string temp_file;

    public bool is_recording {
      get { return _state == State.RECORDING; }
    }

    public RecordingConfig config { get; protected set; }

    private PostProcessingPipeline? pipeline = null;

    private int64 start_time = 0;

    public int64 elapsed_seconds {
      get {
        if (start_time == 0) {
          return 0;
        }

        return (get_monotonic_time () - start_time) / 1000000;
      }
    }

    protected BaseScreenRecorder () {
      config = new RecordingConfig ();
    }

    public void record (RecordingArea area) throws RecordingError {
      cancel ();
      start_recording (area);
      start_time = get_monotonic_time ();
      _state = State.RECORDING;
      recording_started ();
    }

    public void stop () {
      debug ("Recording stopped");

      if (_state == State.RECORDING) {
        _state = State.STOPPING;
        stop_recording ();
      } else {
        cancel ();
      }
    }

    public void cancel () {
      var previous = _state;
      _state = State.IDLE;
      start_time = 0;

      switch (previous) {
        case State.RECORDING:
        case State.STOPPING:
          stop_recording ();
          remove_temp_file ();
          recording_aborted (null);
          break;
        case State.PROCESSING:
          pipeline.cancel ();
          pipeline = null;
          recording_aborted (null);
          break;
        default:
          break;
      }
    }

    protected abstract void start_recording (RecordingArea area) throws RecordingError;
    protected abstract void stop_recording ();

    /**
    * Backend callback: the recording file is complete. Ignored after cancel.
    */
    protected void finalize_recording () {
      if (_state != State.STOPPING) {
        return;
      }

      debug ("Started post processing");
      _state = State.PROCESSING;
      var this_pipeline = build_post_processor_pipeline ();
      pipeline = this_pipeline;
      run_post_processors_async.begin (this_pipeline, (obj, res) => {
        debug ("Finished post processing");
        // After cancel() a new take may already own the state; a superseded
        // callback must only clean up after itself.
        var cancelled = pipeline != this_pipeline;
        if (!cancelled) {
          _state = State.IDLE;
          pipeline = null;
          temp_file = null;
        }

        try {
          var file = run_post_processors_async.end (res);
          if (cancelled) {
            FileUtils.remove (file.get_path ());
            return;
          }
          FileUtils.chmod (file.get_path (), 0644);
          recording_finished (file);
        } catch (RecordingError e) {
          if (!cancelled) {
            recording_aborted (e);
          }
        }
      });
      recording_postprocess_started ();
    }

    /**
    * Backend callback: the recording ended without a usable file.
    */
    protected void recording_failed (RecordingError reason) {
      _state = State.IDLE;
      start_time = 0;
      remove_temp_file ();
      recording_aborted (reason);
    }

    protected virtual PostProcessingPipeline build_post_processor_pipeline () {
      var pipeline = new PostProcessingPipeline ();

      if (config.output_format == OutputFormat.GIF) {
        if (config.gifski_enabled && GifskiPostProcessor.is_available ()) {
          pipeline.add (new ExtractFramesPostProcessor ());
          pipeline.add (new GifskiPostProcessor (config));
        } else if (FfmpegPostProcessor.is_available ()) {
          pipeline.add (new FfmpegPostProcessor (config));
        }
      } else if (config.output_format == OutputFormat.APNG) {
        pipeline.add (new FfmpegPostProcessor (config));
      }

      return pipeline;
    }

    private async File run_post_processors_async (PostProcessingPipeline pipeline) throws RecordingError {
      var files = new Array<File> ();
      files.append_val (File.new_for_path (temp_file));

      // The pipeline deletes its input files, including temp_file.
      files = yield pipeline.process_async (files);

      if (files.length == 0) {
        throw new RecordingError.POSTPROCESSING_ABORTED (
          "Missing output file after post processing.");
      }

      return files.index (0);
    }

    protected void remove_temp_file () {
      if (temp_file != null) {
        FileUtils.remove (temp_file);
        temp_file = null;
      }
    }
  }

}
