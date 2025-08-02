# frozen_string_literal: true

module PageObjects
  module Pages
    class AdminAboutConfigArea < PageObjects::Pages::Base
      def visit
        page.visit("/admin/config/about")
      end

      def general_settings_section
        PageObjects::Components::AdminAboutConfigAreaGeneralSettingsCard.new
      end

      def contact_information_section
        PageObjects::Components::AdminAboutConfigAreaContactInformationCard.new
      end

      def your_organization_section
        PageObjects::Components::AdminAboutConfigAreaYourOrganizationCard.new
      end

      def group_listing_section
        PageObjects::Components::AdminAboutConfigAreaGroupListingCard.new
      end
    end
  end
end
