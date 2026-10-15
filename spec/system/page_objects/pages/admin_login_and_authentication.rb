# frozen_string_literal: true

module PageObjects
  module Pages
    class AdminLoginAndAuthentication < PageObjects::Pages::Base
      def visit(tab = nil)
        if tab.present?
          browser_page
            .goto("/admin/config/login-and-authentication/#{tab}")
            .tap { SystemBrowserBootstrap.wait_for(browser_page) }
        else
          browser_page
            .goto("/admin/config/login-and-authentication")
            .tap { SystemBrowserBootstrap.wait_for(browser_page) }
        end
        self
      end

      def click_tab(tab)
        browser_root
          .locator(
            ".admin-config.login .nav-pills li a[href='/admin/config/login-and-authentication/#{tab}']",
          )
          .filter(visible: true)
          .click
        expect_page_to_be_active(tab)
        self
      end

      def expect_page_to_be_active(tab)
        expect(browser_page).to PlaywrightMatchers.have_url(
          "/admin/config/login-and-authentication/#{tab}",
        )
      end

      def has_setting?(setting_name)
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root.locator(".row.setting[data-setting=\"#{setting_name}\"]").filter(
            visible: true,
          ),
        )
      end
    end
  end
end
