# frozen_string_literal: true

require "fileutils"
require "json"
require "tempfile"
require "tmpdir"
require "zip"

module SystemArtifacts
  def self.record_video(example)
    return unless example.metadata[:video]

    FileUtils.mkdir_p(Capybara.save_path)
    directory = Dir.mktmpdir("system-frames-", Capybara.save_path)
    stop = Queue.new
    driver = Capybara.current_session.driver
    driver.with_browser_page { |_browser| nil }
    recorder =
      Thread.new do
        frame = 0
        loop do
          begin
            driver.save_screenshot(File.join(directory, format("frame-%05d.png", frame)))
            frame += 1
          rescue StandardError
            nil
          end
          break if stop.pop(timeout: 0.25)
        end
      end
    example.metadata[:system_video] = { directory: directory, stop: stop, recorder: recorder }
  end

  def self.stop_video(example)
    recording = example.metadata.delete(:system_video)
    return unless recording

    recording.fetch(:stop) << true
    recording.fetch(:recorder).join
    directory = recording.fetch(:directory)
    path =
      File.join(
        Capybara.save_path,
        "#{example.metadata[:full_description].parameterize}-frames.zip",
      )
    File.delete(path) if File.exist?(path)
    Zip::File.open(path, create: true) do |archive|
      Dir
        .glob(File.join(directory, "*.png"))
        .sort
        .each { |frame| archive.add(File.basename(frame), frame) }
    end
    puts "\n🎥 Browser frames: #{path}\n" unless ENV["CI"]
  ensure
    FileUtils.remove_entry(directory) if directory && File.directory?(directory)
  end

  def self.start_trace(page, example)
    return unless example.metadata[:trace]

    entries = []
    example.metadata[:system_trace] = entries
    page.driver.on(
      "console",
      ->(message) { entries << { type: "console", level: message.type, text: message.text } },
    )
    page.driver.on(
      "pageerror",
      ->(error) { entries << { type: "pageerror", message: error.message } },
    )
    page.driver.on("request", ->(request) { entries << { type: "request", url: request.url } })
  end

  def self.stop_trace(page, example)
    entries = example.metadata.delete(:system_trace)
    return unless entries

    path =
      File.join(Capybara.save_path, "#{example.metadata[:full_description].parameterize}-trace.zip")
    FileUtils.mkdir_p(Capybara.save_path)
    File.delete(path) if File.exist?(path)
    screenshot = Tempfile.new(%w[system-trace- .png])
    begin
      page.driver.save_screenshot(screenshot.path)
      Zip::File.open(path, create: true) do |archive|
        archive.get_output_stream("events.json") do |output|
          output.write(JSON.pretty_generate(entries))
        end
        archive.add("last-page.png", screenshot.path)
      end
    ensure
      screenshot.close!
    end
    puts "\n🧭 Browser trace: #{path}\n" unless ENV["CI"]
  end
end
