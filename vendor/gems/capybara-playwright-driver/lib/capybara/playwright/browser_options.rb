module Capybara
  module Playwright
    class BrowserOptions
      def initialize(options)
        @options = options
      end

      LAUNCH_PARAMS = {
        args: nil,
        channel: nil,
        chromiumSandbox: nil,
        devtools: nil,
        downloadsPath: nil,
        env: nil,
        executablePath: nil,
        firefoxUserPrefs: nil,
        handleSIGHUP: nil,
        handleSIGINT: nil,
        handleSIGTERM: nil,
        headless: nil,
        ignoreDefaultArgs: nil,
        proxy: nil,
        slowMo: nil,
        # timeout: nil,
        tracesDir: nil,
      }.keys

      def value
        @options.select { |k, _| LAUNCH_PARAMS.include?(k) }
      end
    end
  end
end
