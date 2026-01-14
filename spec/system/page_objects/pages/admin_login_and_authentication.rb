# frozen_string_literal: true

module PageObjects
  module Pages
    class AdminLoginAndAuthentication < PageObjects::Pages::Base
      def visit(tab = nil)
        if tab.present?
          page.visit("/admin/config/login-and-authentication/#{tab}")
        else
          page.visit("/admin/config/login-and-authentication")
        end
        self
      end

      def click_tab(tab)
        find(
          ".admin-config.login .nav-pills li a[href='/admin/config/login-and-authentication/#{tab}']",
        ).click
        expect_page_to_be_active(tab)
        self
      end

      def expect_page_to_be_active(tab)
        expect(page).to have_current_path("/admin/config/login-and-authentication/#{tab}")
      end

      def has_setting?(setting_name)
        has_css?(".row.setting[data-setting=\"#{setting_name}\"]")
      end
    end
  end
end
