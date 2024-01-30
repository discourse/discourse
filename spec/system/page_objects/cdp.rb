# frozen_string_literal: true

module PageObjects
  class CDP
    include Capybara::DSL

    def allow_clipboard
      cdp_params = {
        origin: page.server_url,
        permission: {
          name: "clipboard-read",
        },
        setting: "granted",
      }
      page.driver.browser.execute_cdp("Browser.setPermission", **cdp_params)

      cdp_params = {
        origin: page.server_url,
        permission: {
          name: "clipboard-write",
        },
        setting: "granted",
      }
      page.driver.browser.execute_cdp("Browser.setPermission", **cdp_params)
    end

    def read_clipboard
      page.evaluate_async_script("navigator.clipboard.readText().then(arguments[0])")
    end

    def with_network_disconnected
      begin
        page.driver.browser.network_conditions = { offline: true }
        yield
      ensure
        page.driver.browser.network_conditions = { offline: false }
      end
    end

    def with_slow_download
      begin
        page.driver.browser.network_conditions = { latency: 20_000, download_throughput: 1 }
        yield
      ensure
        page.driver.browser.network_conditions = { latency: 0 }
      end
    end

    def with_slow_upload
      begin
        page.driver.browser.network_conditions = { latency: 20_000, upload_throughput: 1 }
        yield
      ensure
        page.driver.browser.network_conditions = { latency: 0 }
      end
    end
  end
end
