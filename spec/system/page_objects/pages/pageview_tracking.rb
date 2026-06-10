# frozen_string_literal: true

module PageObjects
  module Pages
    class PageviewTracking < PageObjects::Pages::Base
      def session_id
        find("meta[name='discourse-track-view-session-id']", visible: :all)[:content]
      end

      # Simulates the user switching to another application. A new tab takes
      # the browser's real focus, then ending Chrome's focus emulation lets
      # the original page notice: the browser itself fires `blur` and reports
      # `document.hasFocus() == false`, the same focus-loss path a real
      # app-switch takes. Headless Chrome has no window manager, so this is
      # the only real leave action available to system tests.
      def switch_to_another_application
        remember_app_page
        page.switch_to_window(page.open_new_window(:tab))
        set_focus_emulation(enabled: false)
      end

      def return_to_page
        page.switch_to_window(@app_window)
        set_focus_emulation(enabled: true)
      end

      # Jumps the page's Date.now() past the exit ping resend throttle using
      # the Playwright clock installed by the `time:` metadata, so tests
      # never wait in real time.
      def skip_past_resend_throttle
        remember_app_page
        @app_pw_page.clock.fast_forward(5_000)
      end

      private

      def remember_app_page
        return if @app_pw_page

        @app_window = page.current_window
        page.driver.with_playwright_page { |pw_page| @app_pw_page = pw_page }
      end

      def set_focus_emulation(enabled:)
        cdp_session = @app_pw_page.context.new_cdp_session(@app_pw_page)
        cdp_session.send_message("Emulation.setFocusEmulationEnabled", params: { enabled: enabled })
      end
    end
  end
end
