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
      require_browser_feature(:clipboard)
      page.driver.with_browser_page do |browser_page|
        if browser_page.respond_to?(:prepare_clipboard)
          browser_page.prepare_clipboard
        else
          browser_page.context.grant_permissions(["clipboard-read"], origin: browser_page.url)
          browser_page.context.grant_permissions(["clipboard-write"], origin: browser_page.url)
        end
      end
    end

    def read_clipboard
      evaluate_clipboard("navigator.clipboard.readText().then(arguments[0])")
    end

    def write_clipboard(content, html: false, plain_text: content)
      if html
        evaluate_clipboard(
          "navigator.clipboard.write([
        new ClipboardItem({
          'text/html': new Blob([arguments[0]], { type: 'text/html' }),
          'text/plain': new Blob([arguments[1]], { type: 'text/plain' })
        })
      ]).then(arguments[2])",
          content,
          plain_text,
        )
      else
        evaluate_clipboard(
          "navigator.clipboard.writeText(arguments[0]).then(arguments[1])",
          content,
        )
      end
    end

    def copy_test_image
      require_browser_feature(:image_clipboard)
      image_path = "spec/fixtures/images/logo.png"
      image_data = File.read(image_path)
      image_base64 = Base64.strict_encode64(image_data)

      evaluate_clipboard(<<~JAVASCRIPT)
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

    def copy_paste(text, html: false, plain_text: text, css_selector: nil)
      allow_clipboard
      write_clipboard(text, html: html, plain_text: plain_text)
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
      require_browser_feature(:offline_emulation)
      window = page.current_window
      page.driver.with_browser_page do |browser_page|
        context = browser_page.context
        context.set_offline(offline: true)
        begin
          yield
        ensure
          page.within_window(window) { context.set_offline(offline: false) } if window.exists?
        end
      end
    end

    # Holds matching requests in-flight for the duration of the block.
    def with_pending_requests(pattern)
      require_browser_feature(:network_interception)
      page.driver.with_browser_page do |browser_page|
        browser_page.route(pattern, ->(_route, _request) {})
        begin
          yield
        ensure
          browser_page.unroute(pattern)
        end
      end
    end

    def with_paused_request(pattern)
      require_browser_feature(:network_interception)
      paused_request = PausedRequest.new
      handler = paused_request.method(:intercept)

      page.driver.with_browser_page do |browser_page|
        browser_page.route(pattern, handler, times: 1)
        begin
          yield(paused_request)
        ensure
          paused_request.resume
          browser_page.unroute(pattern, handler:)
        end
      end
    end

    private

    def evaluate_clipboard(script, *args)
      require_browser_feature(:clipboard)
      if page.driver.respond_to?(:evaluate_clipboard)
        page.driver.evaluate_clipboard(script, *args)
      else
        page.evaluate_async_script(script, *args)
      end
    end
  end
end
