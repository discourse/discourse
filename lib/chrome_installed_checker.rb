# frozen_string_literal: true

require "rbconfig"

class ChromeInstalledChecker
  class ChromeNotInstalled < StandardError; end
  class ChromeVersionTooLow < StandardError; end

  def self.run
    if RbConfig::CONFIG['host_os'][/darwin|mac os/]
      binary = "/Applications/Google\ Chrome.app/Contents/MacOS/Google\ Chrome"
    elsif system("command -v google-chrome-stable >/dev/null;")
      binary = "google-chrome-stable"
    end
    binary ||= "google-chrome" if system("command -v google-chrome >/dev/null;")

    if !binary
      raise ChromeNotInstalled.new("Chrome is not installed. Download from https://www.google.com/chrome/browser/desktop/index.html")
    end

    if Gem::Version.new(`\"#{binary}\" --version`.match(/[\d\.]+/)[0]) < Gem::Version.new("59")
      raise ChromeVersionTooLow.new("Chrome 59 or higher is required")
    end
  end
end
