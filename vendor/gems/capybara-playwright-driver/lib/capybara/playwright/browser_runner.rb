module Capybara
    module Playwright
      # playwright-ruby-client provides 3 methods to launch/connect browser.
      #
      # Playwright.create do |playwright|
      #   playwright.chromium.launch do |browser|
      #
      # Playwright.connect_to_playwright_server do |playwright| ...
      #   playwright.chromium.launch do |browser|
      #
      # Playwright.connect_to_browser_server do |browser| ...
      #
      # This class provides start/stop methods for driver.
      # This is responsible for
      # - managing PlaywrightExecution
      # - launching browser with given option if needed
      class BrowserRunner
        class PlaywrightConnectToPlaywrightServer
          def initialize(endpoint_url, options)
            @ws_endpoint = endpoint_url
            @browser_type = options[:browser_type] || :chromium
            unless %i(chromium firefox webkit).include?(@browser_type)
              raise ArgumentError.new("Unknown browser_type: #{@browser_type}")
            end
            @browser_options = BrowserOptions.new(options)
          end

          def playwright_execution
            @playwright_execution ||= ::Playwright.connect_to_playwright_server("#{@ws_endpoint}?browser=#{@browser_type}")
          end

          def playwright_browser
            browser_type = playwright_execution.playwright.send(@browser_type)
            browser_options = @browser_options.value
            browser_type.launch(**browser_options)
          end
        end

        class PlaywrightConnectToBrowserServer
          def initialize(endpoint_url, options)
            @ws_endpoint = endpoint_url
            @browser_type = options[:browser_type] || :chromium
            unless %i(chromium firefox webkit).include?(@browser_type)
              raise ArgumentError.new("Unknown browser_type: #{@browser_type}")
            end
            @browser_options = BrowserOptions.new(options)
          end

          def playwright_execution
            # requires playwright-ruby-client >= 1.54.1
            @playwright_execution ||= ::Playwright.connect_to_browser_server(@ws_endpoint, browser_type: @browser_type.to_s)
          end

          def playwright_browser
            playwright_execution.browser
          end
        end

        class PlaywrightCreate
          def initialize(options)
            @playwright_cli_executable_path = options[:playwright_cli_executable_path] || 'npx playwright'
            @browser_type = options[:browser_type] || :chromium
            unless %i(chromium firefox webkit).include?(@browser_type)
              raise ArgumentError.new("Unknown browser_type: #{@browser_type}")
            end
            @browser_options = BrowserOptions.new(options)
          end

          def playwright_execution
            @playwright_execution ||= ::Playwright.create(
              playwright_cli_executable_path: @playwright_cli_executable_path,
            )
          end

          def playwright_browser
            browser_type = playwright_execution.playwright.send(@browser_type)
            browser_options = @browser_options.value
            browser_type.launch(**browser_options)
          end
        end

        def initialize(options)
          @runner =
            if options[:playwright_server_endpoint_url]
              PlaywrightConnectToPlaywrightServer.new(options[:playwright_server_endpoint_url], options)
            elsif options[:browser_server_endpoint_url]
              PlaywrightConnectToBrowserServer.new(options[:browser_server_endpoint_url], options)
            else
              PlaywrightCreate.new(options)
            end
        end

        # @return [::Playwright::Browser]
        def start
          @playwright_execution = @runner.playwright_execution
          @runner.playwright_browser
        end

        def stop
          @playwright_execution&.stop
          @playwright_execution = nil
        end
      end
    end
  end
