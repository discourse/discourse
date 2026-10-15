# frozen_string_literal: true

module PageObjects
  module Components
    class AdminCustomizeThemeInstallButton < PageObjects::Components::Base
      def click
        browser_root.locator(".d-page-subheader .btn-primary").filter(visible: true).click
        modal = PageObjects::Modals::InstallTheme.new
        expect(modal).to be_open
        modal
      end
    end
  end
end
