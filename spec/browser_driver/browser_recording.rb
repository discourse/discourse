# frozen_string_literal: true

module NativeBrowserRecording
  def start_trace
    @trace_stream = Queue.new
    command(
      "Tracing.start",
      {
        transferMode: "ReturnAsStream",
        categories:
          "devtools.timeline,blink.user_timing,loading,disabled-by-default-devtools.screenshot",
      },
      browser: true,
    )
  end

  def stop_trace(path)
    return unless @trace_stream
    command("Tracing.end", {}, browser: true)
    stream = @trace_stream.pop(timeout: 10)
    raise SystemBrowserTimeout, "No Chromium tracing stream was returned" unless stream
    File.open(path, "wb") do |output|
      loop do
        chunk = command("IO.read", { handle: stream }, browser: true)
        data = chunk.fetch("data", "")
        output.write(chunk["base64Encoded"] ? Base64.decode64(data) : data)
        break if chunk["eof"]
      end
    end
  ensure
    command("IO.close", { handle: stream }, browser: true) if stream
    @trace_stream = nil
  end

  def start_video
    @recording = Dir.mktmpdir("discourse-screenrecord-")
    @screenshots = []
    command("Page.startScreencast", { format: "jpeg", quality: 70, everyNthFrame: 2 })
  end

  def stop_video(path)
    return unless @recording
    command("Page.stopScreencast")
    raise SystemBrowserError, "Chromium produced no frames for the recording" if @screenshots.empty?
    frames = File.join(@recording, "frames.txt")
    File.open(frames, "w") do |list|
      @screenshots.each_with_index do |(name, timestamp), index|
        following = @screenshots[index + 1]&.last
        duration = following && timestamp ? [following - timestamp, 0.04].max : 0.04
        list.puts "file '#{name}'", "duration #{duration}"
      end
      list.puts "file '#{@screenshots.last.first}'"
    end
    system(
      ENV.fetch("FFMPEG_PATH", "ffmpeg"),
      "-hide_banner",
      "-loglevel",
      "error",
      "-y",
      "-f",
      "concat",
      "-i",
      frames,
      "-fps_mode",
      "vfr",
      "-c:v",
      "libvpx-vp9",
      path,
      exception: true,
    )
  rescue Errno::ENOENT
    raise SystemBrowserError, "Install ffmpeg or set FFMPEG_PATH to record system specs."
  ensure
    FileUtils.remove_entry(@recording) if @recording
    @recording = @screenshots = nil
  end

  private

  def record_screen_frame(params, session)
    if @recording
      filename = "#{@screenshots.size}.jpg"
      File.binwrite(File.join(@recording, filename), Base64.decode64(params.fetch("data")))
      @screenshots << [filename, params.dig("metadata", "timestamp")]
    end
    @client.notify("Page.screencastFrameAck", { sessionId: params.fetch("sessionId") }, session:)
  end
end
