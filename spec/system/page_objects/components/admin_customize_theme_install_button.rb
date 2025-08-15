# frozen_string_literal: true

module PageObjects
  module Components
    class AdminCustomizeThemeInstallButton < PageObjects::Components::Base
      def click
        find(".d-page-subheader .btn-primary").click
        modal = PageObjects::Modals::InstallTheme.new
        expect(modal).to be_open
        modal
      end
    end
  end
end
