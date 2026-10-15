# frozen_string_literal: true

module PageObjects
  module Pages
    class UserPreferencesSecurity < PageObjects::Pages::Base
      def visit(user)
        browser_page
          .goto("/u/#{user.username}/preferences/security")
          .tap { SystemBrowserBootstrap.wait_for(browser_page) }
        self
      end

      def click_manage_2fa_authentication
        browser_root
          .locator(
            "[id=#{"Manage Two-Factor Authentication".to_s.to_json}], [name=#{"Manage Two-Factor Authentication".to_s.to_json}]",
          )
          .or(browser_root.get_by_role("button", name: "Manage Two-Factor Authentication"))
          .filter(visible: true)
          .click
        PageObjects::Modals::ConfirmSession.new
      end

      def visit_second_factor(user, password)
        click_manage_2fa_authentication.submit_password(password)

        expect(browser_page).to PlaywrightMatchers.have_url(
          "/u/#{user.username}/preferences/second-factor",
        )
        self
      end
    end
  end
end
