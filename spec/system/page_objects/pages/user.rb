# frozen_string_literal: true

module PageObjects
  module Pages
    class User < PageObjects::Pages::Base
      def visit(user)
        browser_page
          .goto("/u/#{user.username}")
          .tap { SystemBrowserBootstrap.wait_for(browser_page) }
        self
      end

      def find(selector)
        browser_root.locator(".new-user-wrapper #{selector}").filter(visible: true)
      end

      def active_user_primary_navigation
        browser_root.locator(".user-navigation-primary li a.active").filter(visible: true)
      end

      def active_user_secondary_navigation
        browser_root.locator(".user-navigation-secondary li a.active").filter(visible: true)
      end

      def has_warning_messages_path?(user)
        PlaywrightMatchers.have_url("/u/#{user.username}/messages/warnings").matches?(browser_page)
      end

      def has_primary_navigation_item?(name)
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root.locator(primary_navigation_selector(name)).filter(visible: true),
        )
      end

      def has_no_primary_navigation_item?(name)
        PlaywrightMatchers.have_count(0).matches?(
          browser_root.locator(primary_navigation_selector(name)).filter(visible: true),
        )
      end

      def has_secondary_navigation_item?(name)
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root.locator(secondary_navigation_selector(name)).filter(visible: true),
        )
      end

      def has_no_secondary_navigation_item?(name)
        PlaywrightMatchers.have_count(0).matches?(
          browser_root.locator(secondary_navigation_selector(name)).filter(visible: true),
        )
      end

      def click_staff_info_warnings_link(user, warnings_count: 0)
        staff_counters = browser_root.locator(".staff-counters").filter(visible: true)
        staff_counters
          .locator("a[href='/u/#{user.username}/messages/warnings']")
          .filter(visible: true)
          .click
        self
      end

      def click_staff_info_silencings_link
        staff_counters = browser_root.locator(".staff-counters").filter(visible: true)
        staff_counters.locator("a:has(.silencings)").filter(visible: true).click
        self
      end

      def click_staff_info_flags_link
        browser_root.locator(".staff-counters .flags").filter(visible: true).click
        self
      end

      def has_staff_counter_flags?(count:)
        PlaywrightMatchers.contain_text(
          [browser_text_pattern(count.to_s)],
          useInnerText: true,
        ).matches?(browser_root.locator(".staff-counters .flags").filter(visible: true))
      end

      def click_staff_info_flags_given_link
        browser_root.locator(".staff-counters .helpful-flags").filter(visible: true).click
        self
      end

      def has_staff_counter_flags_given?(count:)
        PlaywrightMatchers.contain_text(
          [browser_text_pattern(count.to_s)],
          useInnerText: true,
        ).matches?(browser_root.locator(".staff-counters .helpful-flags").filter(visible: true))
      end

      def expand_info_panel
        button =
          browser_root.locator("button[aria-controls='collapsed-info-panel']").filter(visible: true)
        button.click if button.get_attribute("aria-expanded") == "false"
        self
      end

      def click_primary_navigation_item(name)
        browser_root.locator(primary_navigation_selector(name)).filter(visible: true).click
      end

      private

      def primary_navigation_selector(name)
        ".new-user-wrapper .user-navigation-primary li.user-nav__#{name}"
      end

      def secondary_navigation_selector(name)
        ".new-user-wrapper .user-navigation-secondary li.user-nav__#{name}"
      end
    end
  end
end
