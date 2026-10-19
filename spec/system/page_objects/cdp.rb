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

    include NativeSystemHelpers
    include SystemHelpers
    include RSpec::Matchers

    def allow_clipboard
      browser_page.then do |pw_page|
        pw_page.context.grant_permissions(["clipboard-read"], origin: pw_page.url)
        pw_page.context.grant_permissions(["clipboard-write"], origin: pw_page.url)
      end
    end

    def read_clipboard
      browser_page.evaluate(
        "function(args) { return new Promise(resolve => { args.push(resolve); (function() { navigator.clipboard.readText().then(arguments[0]) }).apply(this, args); }); }",
        arg: [],
      )
    end

    def write_clipboard(content, html: false, plain_text: content)
      if html
        browser_page.evaluate(
          "function(args) { return new Promise(resolve => { args.push(resolve); (function() { #{
            "navigator.clipboard.write([
        new ClipboardItem({
          'text/html': new Blob([arguments[0]], { type: 'text/html' }),
          'text/plain': new Blob([arguments[1]], { type: 'text/plain' })
        })
      ]).then(arguments[2])"
          } }).apply(this, args); }); }",
          arg: browser_arguments(content, plain_text),
        )
      else
        browser_page.evaluate(
          "function(args) { return new Promise(resolve => { args.push(resolve); (function() { navigator.clipboard.writeText(arguments[0]).then(arguments[1]) }).apply(this, args); }); }",
          arg: browser_arguments(content),
        )
      end
    end

    def copy_test_image
      image_path = "spec/fixtures/images/logo.png"
      image_data = File.read(image_path)
      image_base64 = Base64.strict_encode64(image_data)

      browser_page.evaluate(
        "function(args) { return new Promise(resolve => { args.push(resolve); (function() { #{
          <<~JAVASCRIPT
        const htmlBlob = new Blob(['<img src="data:image/png;base64,placeholder"/>'], { type: 'text/html' });
        const imageBlob = new Blob([Uint8Array.from(atob("#{image_base64}"), c => c.charCodeAt(0))], { type: 'image/png' });
        const item = new ClipboardItem({ 'text/html': htmlBlob, 'image/png': imageBlob });

        navigator.clipboard.write([item]).then(arguments[0]).catch(console.error);
      JAVASCRIPT
        } }).apply(this, args); }); }",
        arg: [],
      )
    end

    def clipboard_has_text?(text, chomp: false, strict: true)
      clipboard_text = chomp ? read_clipboard.chomp : read_clipboard
      expect(clipboard_text).to strict ? eq(text) : include(text)
    end

    def copy_paste(text, html: false, plain_text: text, css_selector: nil)
      allow_clipboard
      write_clipboard(text, html: html, plain_text: plain_text)
      paste(css_selector:)
    end

    def paste(css_selector: nil)
      if css_selector
        browser_root
          .locator(css_selector)
          .filter(visible: true)
          .press(
            [(SystemHelpers::PLATFORM_KEY_MODIFIER == :meta ? "Meta" : "Control"), "v"].join("+"),
          )
      else
        browser_page.keyboard.press(
          [(SystemHelpers::PLATFORM_KEY_MODIFIER == :meta ? "Meta" : "Control"), "v"].join("+"),
        )
      end
    end

    def with_network_disconnected
      browser_page.then do |pw_page|
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
      browser_page.then do |pw_page|
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
      browser_page.then do |pw_page|
        cdp_client = pw_page.context.new_cdp_session(pw_page)

        cdp_client.send_message(
          "Network.emulateNetworkConditions",
          params: {
            offline: false,
            latency: 0,
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
      browser_page.then do |pw_page|
        pw_page.route(pattern, ->(_route, _request) {})
        yield
      ensure
        pw_page.unroute(pattern)
      end
    end

    def with_paused_request(pattern)
      paused_request = PausedRequest.new
      handler = paused_request.method(:intercept)

      browser_page.then do |pw_page|
        pw_page.route(pattern, handler, times: 1)
        yield(paused_request)
      ensure
        paused_request.resume
        pw_page.unroute(pattern, handler:)
      end
    end
  end
end
