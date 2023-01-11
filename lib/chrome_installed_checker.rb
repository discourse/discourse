# frozen_string_literal: true

require "rbconfig"

class ChromeInstalledChecker
  class ChromeError < StandardError
  end
  class ChromeVersionError < ChromeError
  end
  class ChromeNotInstalled < ChromeError
  end
  class ChromeVersionTooLow < ChromeError
  end

  def self.run
    if RbConfig::CONFIG["host_os"][/darwin|mac os/]
      binary = "/Applications/Google\ Chrome.app/Contents/MacOS/Google\ Chrome"
    elsif system("command -v google-chrome-stable >/dev/null;")
      binary = "google-chrome-stable"
    end
    binary ||= "google-chrome" if system("command -v google-chrome >/dev/null;")
    binary ||= "chromium" if system("command -v chromium >/dev/null;")

    if !binary
      raise ChromeNotInstalled.new(
              "Chrome is not installed. Download from https://www.google.com/chrome/browser/desktop/index.html",
            )
    end

    version = `\"#{binary}\" --version`
    version_match = version.match(/[\d\.]+/)

    raise ChromeError.new("Can't get the #{binary} version") if !version_match

    if Gem::Version.new(version_match[0]) < Gem::Version.new("59")
      raise ChromeVersionTooLow.new("Chrome 59 or higher is required")
    end
  end
end
