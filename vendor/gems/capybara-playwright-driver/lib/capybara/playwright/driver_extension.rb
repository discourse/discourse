module Capybara
  module Playwright
    module DriverExtension
      # Register screenshot save process.
      # The callback is called just before page is closed.
      # (just before #reset_session!)
      #
      # The **binary** (String) of the page screenshot is called back into the given block
      def on_save_raw_screenshot_before_reset(&block)
        @callback_on_save_screenshot = block
      end

      private def callback_on_save_screenshot?
        !!@callback_on_save_screenshot
      end

      private def callback_on_save_screenshot(raw_screenshot)
        @callback_on_save_screenshot&.call(raw_screenshot)
      end

      # Register screenrecord save process.
      # The callback is called just after page is closed.
      # (just after #reset_session!)
      #
      # The video path (String) is called back into the given block
      def on_save_screenrecord(&block)
        @callback_on_save_screenrecord = block
      end

      private def callback_on_save_screenrecord?
        !!@callback_on_save_screenrecord
      end

      private def callback_on_save_screenrecord(video_path)
        @callback_on_save_screenrecord&.call(video_path)
      end

      # Register trace save process.
      # The callback is called just after trace is saved.
      #
      # The trace.zip path (String) is called back into the given block
      def on_save_trace(&block)
        @callback_on_save_trace = block
      end

      def with_playwright_page(&block)
        raise ArgumentError.new('block must be given') unless block

        browser.with_playwright_page(&block)
      end

      # Start Playwright tracing (doc: https://playwright.dev/docs/api/class-tracing#tracing-start)
      def start_tracing(name: nil, screenshots: false, snapshots: false, sources: false, title: nil)
        # Ensure playwright page is initialized.
        browser

        with_playwright_page do |playwright_page|
          playwright_page.context.tracing.start(name: name, screenshots: screenshots, snapshots: snapshots, sources: sources, title: title)
        end
      end

      # Stop Playwright tracing (doc: https://playwright.dev/docs/api/class-tracing#tracing-stop)
      def stop_tracing(path: nil)
        with_playwright_page do |playwright_page|
          playwright_page.context.tracing.stop(path: path)
        end
      end

      # Trace execution of the given block. The tracing is automatically stopped when the block is finished.
      def trace(name: nil, screenshots: false, snapshots: false, sources: false, title: nil, path: nil, &block)
        raise ArgumentError.new('block must be given') unless block

        start_tracing(name: name, screenshots: screenshots, snapshots: snapshots, sources: sources, title: title)
        block.call
      ensure
        stop_tracing(path: path)
      end
    end
  end
end
