require_relative './driver_extension'

module Capybara
  module Playwright
    class Driver < ::Capybara::Driver::Base
      extend Forwardable
      include DriverExtension

      def initialize(app, **options)
        @browser_runner = BrowserRunner.new(options)
        @page_options = PageOptions.new(options)
        if options[:timeout].is_a?(Numeric) # just for compatibility with capybara-selenium-driver
          @default_navigation_timeout = options[:timeout] * 1000
        end
        if options[:default_timeout].is_a?(Numeric)
          @default_timeout = options[:default_timeout] * 1000
        end
        if options[:default_navigation_timeout].is_a?(Numeric)
          @default_navigation_timeout = options[:default_navigation_timeout] * 1000
        end
        @internal_logger = options[:logger] || default_logger
      end

      def wait?; true; end
      def needs_server?; true; end

      private def browser
        @browser ||= ::Capybara::Playwright::Browser.new(
          driver: self,
          internal_logger: @internal_logger,
          playwright_browser: playwright_browser,
          page_options: @page_options.value,
          record_video: callback_on_save_screenrecord?,
          callback_on_save_trace: @callback_on_save_trace,
          default_timeout: @default_timeout,
          default_navigation_timeout: @default_navigation_timeout,
        )
      end

      private def playwright_browser
        @playwright_browser ||= create_playwright_browser
      end

      private def create_playwright_browser
        # clean up @playwright_browser and @playwright_execution on exit.
        main = Process.pid
        at_exit do
          # Store the exit status of the test run since it goes away after calling the at_exit proc...
          @exit_status = $ERROR_INFO.status if $ERROR_INFO.is_a?(SystemExit)
          quit if Process.pid == main
          exit @exit_status if @exit_status # Force exit with stored status
        end

        @browser_runner.start
      end

      private def default_logger
        if defined?(Rails)
          Rails.logger
        else
          PutsLogger.new
        end
      end

      # Since existing user already monkey-patched Kernel#puts,
      # (https://gist.github.com/searls/9caa12f66c45a72e379e7bfe4c48405b)
      # Logger.new(STDOUT) should be avoided to use.
      class PutsLogger
        def info(message)
          puts "[INFO] #{message}"
        end

        def warn(message)
          puts "[WARNING] #{message}"
        end
      end

      private def quit
        @playwright_browser&.close
        @playwright_browser = nil
        @browser_runner.stop
      end

      def reset!
        # screenshot is available only before closing page.
        if callback_on_save_screenshot?
          raw_screenshot = @browser&.raw_screenshot
          if raw_screenshot
            callback_on_save_screenshot(raw_screenshot)
          end
        end

        return if soft_reset_allowed? && @browser&.soft_reset!

        # video path can be acquired only before closing context.
        # video is completely saved only after closing context.
        video_path = @browser&.video_path

        # [NOTE] @playwright_browser should keep alive for better performance.
        # Only `Browser` is disposed.
        @browser&.clear_browser_contexts

        if video_path
          callback_on_save_screenrecord(video_path)
        end

        @browser = nil
      end

      # Force the next #reset! to dispose the browser context instead of
      # soft-resetting it. Test helpers must call this after mutating
      # context-scoped state that has no clearing API (e.g. Playwright's
      # Clock, which cannot be uninstalled once installed).
      def require_hard_reset!
        @hard_reset_required = true
      end

      private def soft_reset_allowed?
        return false if ENV['CAPYBARA_PLAYWRIGHT_SOFT_RESET'] == '0'
        # Video is finalized, and traces collected, only on context close.
        return false if callback_on_save_screenrecord?
        return false if @callback_on_save_trace

        if @hard_reset_required
          @hard_reset_required = false
          return false
        end

        true
      end

      def invalid_element_errors
        @invalid_element_errors ||= [
          Node::NotActionableError,
          Node::StaleReferenceError,
        ].freeze
      end

      def no_such_window_error
        Browser::NoSuchWindowError
      end

      # ref: https://github.com/teamcapybara/capybara/blob/master/lib/capybara/driver/base.rb
      def_delegator(:browser, :current_url)
      def_delegator(:browser, :visit)
      def_delegator(:browser, :refresh)
      def_delegator(:browser, :find_xpath)
      def_delegator(:browser, :find_css)
      def_delegator(:browser, :title)
      def_delegator(:browser, :html)
      def_delegator(:browser, :go_back)
      def_delegator(:browser, :go_forward)
      def_delegator(:browser, :execute_script)
      def_delegator(:browser, :evaluate_script)
      def_delegator(:browser, :evaluate_async_script)
      def_delegator(:browser, :save_screenshot)
      def_delegator(:browser, :response_headers)
      def_delegator(:browser, :status_code)
      def_delegator(:browser, :active_element)
      def_delegator(:browser, :send_keys)
      def_delegator(:browser, :switch_to_frame)
      def_delegator(:browser, :current_window_handle)
      def_delegator(:browser, :window_size)
      def_delegator(:browser, :resize_window_to)
      def_delegator(:browser, :maximize_window)
      def_delegator(:browser, :fullscreen_window)
      def_delegator(:browser, :close_window)
      def_delegator(:browser, :window_handles)
      def_delegator(:browser, :open_new_window)
      def_delegator(:browser, :switch_to_window)
      def_delegator(:browser, :accept_modal)
      def_delegator(:browser, :dismiss_modal)
    end
  end
end
