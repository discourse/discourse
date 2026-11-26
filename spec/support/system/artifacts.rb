# frozen_string_literal: true

module SystemArtifacts
  def self.start(page, example)
    if example.metadata[:trace]
      unless page.driver.respond_to?(:start_trace)
        raise Capybara::NotSupportedByDriverError, "Browser traces require Chromium."
      end
      page.driver.start_trace
    end
    if example.metadata[:video]
      unless page.driver.respond_to?(:start_video)
        raise Capybara::NotSupportedByDriverError, "Browser recordings require Chromium."
      end
      page.driver.start_video
    end
  end

  def self.stop(page, example)
    if example.metadata[:trace] && page.driver.respond_to?(:stop_trace)
      path = artifact_path(example, "trace.json")
      page.driver.stop_trace(path)
      puts "Trace saved at #{path}" unless ENV["CI"]
    end
  ensure
    if example.metadata[:video] && page.driver.respond_to?(:stop_video)
      path = artifact_path(example, "screenrecord.webm")
      page.driver.stop_video(path)
      puts "Recording saved at #{path}" unless ENV["CI"]
    end
  end

  def self.artifact_path(example, suffix)
    FileUtils.mkdir_p(Capybara.save_path)
    File.join(Capybara.save_path, "#{example.metadata[:full_description].parameterize}-#{suffix}")
  end
  private_class_method :artifact_path
end
