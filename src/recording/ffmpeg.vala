/*
Peek Copyright (c) 2015-2018 by Philipp Wolfer <ph.wolfer@gmail.com>

This file is part of Peek.

This software is licensed under the GNU General Public License
(version 3 or later). See the LICENSE file in this distribution.
*/

namespace Peek.Recording.Ffmpeg {
  public void add_output_parameters (
    Array<string> args, RecordingConfig config, out string extension) {
    if (config.output_format == OutputFormat.WEBM) {
      extension = Utils.get_file_extension_for_format (config.output_format);
      args.append_val ("-codec:v");
      args.append_val ("libvpx-vp9");
      args.append_val ("-qmin");
      args.append_val ("10");
      args.append_val ("-qmax");
      args.append_val ("50");
      args.append_val ("-crf");
      args.append_val ("13");
      args.append_val ("-b:v");
      args.append_val ("1M");
      args.append_val ("-pix_fmt");
      args.append_val ("yuv420p");
    } else if (config.output_format == OutputFormat.MP4) {
      extension = Utils.get_file_extension_for_format (config.output_format);
      args.append_val ("-codec:v");
      args.append_val ("libx264");
      args.append_val ("-preset:v");
      args.append_val ("fast");
      args.append_val ("-profile:v");
      args.append_val ("baseline");
      args.append_val ("-pix_fmt");
      args.append_val ("yuv420p");
    } else {
      // Lossless RGB intermediate for GIF/APNG. libvpx-vp9 -lossless 1 runs
      // at ~1x realtime for 1080p even on 16 cores, so x11grab dropped
      // frames; x264rgb ultrafast is >10x faster and keeps exact colors.
      extension = "mkv";
      args.append_val ("-codec:v");
      args.append_val ("libx264rgb");
      args.append_val ("-qp");
      args.append_val ("0");
      args.append_val ("-preset");
      args.append_val ("ultrafast");
    }

    args.append_val ("-r");
    args.append_val (config.framerate.to_string ());
  }
}
