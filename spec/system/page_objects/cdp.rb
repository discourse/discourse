# frozen_string_literal: true

module PageObjects
  class CDP
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
      try_until_success do
        clipboard_text = chomp ? read_clipboard.chomp : read_clipboard
        expect(clipboard_text).to strict ? eq(text) : include(text)
      end
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
        begin
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
    end

    def with_slow_download
      page.driver.with_playwright_page do |pw_page|
        begin
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
    end

    def with_slow_upload
      page.driver.with_playwright_page do |pw_page|
        begin
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
    end
  end
end
