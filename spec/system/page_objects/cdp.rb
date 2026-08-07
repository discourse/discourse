# frozen_string_literal: true

module PageObjects
  class CDP
    class PausedRequest
      def initialize
        @request_started = Queue.new
        @resume_request = Queue.new
        @resumed = false
      end

      def intercept(route, _request)
        @request_started << true
        @resume_request.pop
        route.continue
      end

      def wait
        return if @request_started.pop(timeout: Capybara.default_max_wait_time)

        raise Capybara::ExpectationNotMet, "Timed out waiting for the paused request"
      end

      def resume
        return if @resumed

        @resumed = true
        @resume_request << true
      end
    end
    private_constant :PausedRequest

    include Capybara::DSL
    include SystemHelpers
    include RSpec::Matchers

    def allow_clipboard
      page.driver.with_playwright_page do |pw_page|
        pw_page.context.grant_permissions(["clipboard-read"], origin: pw_page.url)
        pw_page.context.grant_permissions(["clipboard-write"], origin: pw_page.url)
      end
    end

    def read_clipboard
      page.evaluate_async_script("navigator.clipboard.readText().then(arguments[0])")
    end

    def write_clipboard(content, html: false)
      if html
        page.evaluate_async_script(
          "navigator.clipboard.write([
        new ClipboardItem({
          'text/html': new Blob([arguments[0]], { type: 'text/html' }),
          'text/plain': new Blob([arguments[0]], { type: 'text/plain' })
        })
      ]).then(arguments[1])",
          content,
        )
      else
        page.evaluate_async_script(
          "navigator.clipboard.writeText(arguments[0]).then(arguments[1])",
          content,
        )
      end
    end

    def copy_test_image
      image_path = "spec/fixtures/images/logo.png"
      image_data = File.read(image_path)
      image_base64 = Base64.strict_encode64(image_data)

      page.evaluate_async_script(<<~JAVASCRIPT)
        const htmlBlob = new Blob(['<img src="data:image/png;base64,placeholder"/>'], { type: 'text/html' });
        const imageBlob = new Blob([Uint8Array.from(atob("#{image_base64}"), c => c.charCodeAt(0))], { type: 'image/png' });
        const item = new ClipboardItem({ 'text/html': htmlBlob, 'image/png': imageBlob });

        navigator.clipboard.write([item]).then(arguments[0]).catch(console.error);
      JAVASCRIPT
    end

    def clipboard_has_text?(text, chomp: false, strict: true)
      clipboard_text = chomp ? read_clipboard.chomp : read_clipboard
      expect(clipboard_text).to strict ? eq(text) : include(text)
    end

    def copy_paste(text, html: false, css_selector: nil)
      allow_clipboard
      write_clipboard(text, html: html)
      paste(css_selector:)
    end

    def paste(css_selector: nil)
      if css_selector
        find(css_selector).send_keys([PLATFORM_KEY_MODIFIER, "v"])
      else
        page.send_keys([PLATFORM_KEY_MODIFIER, "v"])
      end
    end

    def with_network_disconnected
      page.driver.with_playwright_page do |pw_page|
        cdp_client = pw_page.context.new_cdp_session(pw_page)

        cdp_client.send_message(
          "Network.emulateNetworkConditions",
          params: {
            offline: true,
            latency: 0,
            downloadThroughput: -1,
            uploadThroughput: -1,
          },
        )

        yield
      ensure
        cdp_client.send_message(
          "Network.emulateNetworkConditions",
          params: {
            offline: false,
            latency: 0,
            downloadThroughput: -1,
            uploadThroughput: -1,
          },
        )
      end
    end

    def with_slow_download
      page.driver.with_playwright_page do |pw_page|
        cdp_client = pw_page.context.new_cdp_session(pw_page)

        cdp_client.send_message(
          "Network.emulateNetworkConditions",
          params: {
            offline: false,
            latency: 20_000,
            downloadThroughput: 1,
            uploadThroughput: -1,
          },
        )

        yield
      ensure
        cdp_client.send_message(
          "Network.emulateNetworkConditions",
          params: {
            offline: false,
            latency: 0,
            downloadThroughput: -1,
            uploadThroughput: -1,
          },
        )
      end
    end

    def with_slow_upload
      page.driver.with_playwright_page do |pw_page|
        cdp_client = pw_page.context.new_cdp_session(pw_page)

        cdp_client.send_message(
          "Network.emulateNetworkConditions",
          params: {
            offline: false,
            latency: 20_000,
            downloadThroughput: -1,
            uploadThroughput: 1,
          },
        )

        yield
      ensure
        cdp_client.send_message(
          "Network.emulateNetworkConditions",
          params: {
            offline: false,
            latency: 0,
            downloadThroughput: -1,
            uploadThroughput: -1,
          },
        )
      end
    end

    # Holds matching requests in-flight for the duration of the block.
    def with_pending_requests(pattern)
      page.driver.with_playwright_page do |pw_page|
        pw_page.route(pattern, ->(_route, _request) {})
        yield
      ensure
        pw_page.unroute(pattern)
      end
    end

    def with_paused_request(pattern)
      paused_request = PausedRequest.new
      handler = paused_request.method(:intercept)

      page.driver.with_playwright_page do |pw_page|
        pw_page.route(pattern, handler, times: 1)
        yield(paused_request)
      ensure
        paused_request.resume
        pw_page.unroute(pattern, handler:)
      end
    end
  end
end
