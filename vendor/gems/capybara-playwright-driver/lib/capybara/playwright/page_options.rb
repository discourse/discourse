module Capybara
  module Playwright
    class PageOptions
      def initialize(options)
        @options = options
      end

      NEW_PAGE_PARAMS = {
        acceptDownloads: nil,
        bypassCSP: nil,
        colorScheme: nil,
        deviceScaleFactor: nil,
        extraHTTPHeaders: nil,
        geolocation: nil,
        hasTouch: nil,
        httpCredentials: nil,
        ignoreHTTPSErrors: nil,
        isMobile: nil,
        javaScriptEnabled: nil,
        locale: nil,
        noViewport: nil,
        offline: nil,
        permissions: nil,
        proxy: nil,
        record_har_omit_content: nil,
        record_har_path: nil,
        record_video_dir: nil,
        record_video_size: nil,
        reducedMotion: nil,
        screen: nil,
        serviceWorkers: nil,
        storageState: nil,
        timezoneId: nil,
        userAgent: nil,
        viewport: nil,
      }.keys

      def value
        @options.select { |k, _| NEW_PAGE_PARAMS.include?(k) }.tap do |options|
          # Set default value
          options[:acceptDownloads] = true
        end
      end
    end
  end
end
