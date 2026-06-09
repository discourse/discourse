# frozen_string_literal: true

# Per-example debugging artifacts for system specs, captured when the example is
# tagged `video: true` or `trace: true`.
module SystemArtifacts
  # Save a screen recording for the example.
  def self.record_video(example)
    return unless example.metadata[:video]

    Capybara.current_session.driver.on_save_screenrecord do |video|
      saved_path =
        File.join(
          Capybara.save_path,
          "#{example.metadata[:full_description].parameterize}-screenrecord.webm",
        )

      FileUtils.mv(video, saved_path)

      if !ENV["CI"]
        puts "\n🎥 Recorded video for: #{example.metadata[:full_description]}\n"
        puts "#{saved_path}\n"
      end
    end
  end

  # Start a Playwright trace for the example.
  def self.start_trace(page, example)
    return unless example.metadata[:trace]

    page.driver.start_tracing(screenshots: true, snapshots: true, sources: true)
  end

  # Stop and save the Playwright trace (paired with start_trace).
  def self.stop_trace(page, example)
    return unless example.metadata[:trace]

    path =
      File.join(Capybara.save_path, "#{example.metadata[:full_description].parameterize}-trace.zip")
    page.driver.stop_tracing(path:)

    if !ENV["CI"]
      puts "\n🧭 Recorded trace for: #{example.metadata[:full_description]}\n"
      puts "Open with `pnpm playwright show-trace #{path}`\n"
    end
  end
end
