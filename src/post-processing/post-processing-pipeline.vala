/*
Peek Copyright (c) 2017 by Philipp Wolfer <ph.wolfer@gmail.com>

This file is part of Peek.

This software is licensed under the GNU General Public License
(version 3 or later). See the LICENSE file in this distribution.
*/

namespace Peek.PostProcessing {

  /**
  * Runs post processors in sequence, feeding each one the previous output
  * and deleting the intermediate files. Cancelling kills the active step,
  * which then fails with POSTPROCESSING_ABORTED like any other error.
  */
  public class PostProcessingPipeline : Object, PostProcessor {
    private Array<PostProcessor> pipeline = new Array<PostProcessor> ();
    private PostProcessor? active_post_processor = null;
    private bool cancelled = false;

    public void add (PostProcessor post_processor) {
      pipeline.append_val (post_processor);
    }

    public async Array<File> process_async (Array<File> files) throws RecordingError {
      foreach (var post_processor in pipeline.data) {
        // cancel() may have arrived while the previous step's files were
        // being deleted, with nothing running to kill.
        if (cancelled) {
          throw new RecordingError.POSTPROCESSING_ABORTED ("Post processing cancelled.");
        }

        debug ("Running post processor %s with %u files", post_processor.get_type ().name (), files.length);

        var input = files;
        active_post_processor = post_processor;
        try {
          files = yield post_processor.process_async (input);
        } finally {
          active_post_processor = null;
          foreach (var file in input.data) {
            try {
              yield file.delete_async ();
            } catch (Error e) {
              stderr.printf ("Error deleting temporary file %s: %s\n", file.get_path (), e.message);
            }
          }
        }
      }

      return files;
    }

    public void cancel () {
      cancelled = true;
      if (active_post_processor != null) {
        active_post_processor.cancel ();
      }
    }
  }
}
