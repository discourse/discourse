# frozen_string_literal: true

# Included in all system specs (via rails_helper) to provide screenshot_marker.
#
# Usage:
#   it "opens the composer" do
#     # ... set up state ...
#     screenshot_marker(label: "composer-open")
#     # ... assertions ...
#   end
#
# screenshot_marker is a no-op unless TAKE_SCREENSHOTS=1 is set.
# Output lands in tmp/theme-screenshots/raw/ (or SCREENSHOTS_DIR/raw/).
#
# When run via the theme_screenshots_spec matrix runner, SCREENSHOTS_THEME_ID,
# SCREENSHOTS_THEME_NAME, SCREENSHOTS_MODE, and SCREENSHOTS_DEVICE are injected
# internally as env vars. The before hook sets SiteSetting.default_theme_id so
# every subsequent page visit in the example renders with the correct theme.
#
module ThemeScreenshotMarker
  def self.included(base)
    base.before do
      next unless ENV["TAKE_SCREENSHOTS"] == "1"

      SiteSetting.global_notice = ""

      if (theme_id = ENV["SCREENSHOTS_THEME_ID"].presence&.to_i) && theme_id != 0
        SiteSetting.default_theme_id = theme_id
      end

      if (mode = ENV["SCREENSHOTS_MODE"].presence)
        page.driver.with_playwright_page { |pw_page| pw_page.emulate_media(colorScheme: mode) }
      end

      page.driver.with_playwright_page do |pw_page|
        pw_page.add_style_tag(content: "#global-notice-theme-preview { display: none !important; }")
      end
    end
  end

  # `only:` constrains which device leg of the matrix the screenshot belongs
  # to. Use it for features that don't exist on the other device (e.g. the
  # full search menu is desktop-only). The orchestrator parses this kwarg
  # from the source to also skip the surrounding example on the wrong leg —
  # this in-method check is a belt-and-braces fallback.
  def screenshot_marker(label:, only: nil)
    return unless ENV["TAKE_SCREENSHOTS"] == "1"

    device = ENV["SCREENSHOTS_DEVICE"] || "desktop"

    return if only && only.to_s != device

    output_dir = ENV["SCREENSHOTS_DIR"] || Rails.root.join("tmp/theme-screenshots").to_s
    raw_dir = File.join(output_dir, "raw")
    FileUtils.mkdir_p(raw_dir)
    theme_name = ENV["SCREENSHOTS_THEME_NAME"] || "default"
    mode = ENV["SCREENSHOTS_MODE"] || "light"

    page.driver.with_playwright_page do |pw_page|
      unless @message_bus_blocked
        pw_page.route(%r{/message-bus/}, ->(route, _request) { route.abort })
        @message_bus_blocked = true
      end
      pw_page.wait_for_load_state(state: "networkidle", timeout: 10_000)
    rescue Playwright::TimeoutError
      # page is visually complete; a stray background request is still open
    end

    filename = File.join(raw_dir, "#{device}-#{theme_name}-#{mode}-#{label}.png")

    page.driver.with_playwright_page do |pw_page|
      pw_page.set_viewport_size(width: pw_page.viewport_size[:width], height: 1200)
      pw_page.screenshot(path: filename)
    end

    puts "📸 #{filename}"
  end
end
