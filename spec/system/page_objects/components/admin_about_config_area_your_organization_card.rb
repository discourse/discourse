# frozen_string_literal: true

module PageObjects
  module Components
    class AdminAboutConfigAreaYourOrganizationCard < PageObjects::Components::Base
      def company_name_input
        card.find(".company-name-input input")
      end

      def governing_law_input
        card.find(".governing-law-input input")
      end

      def city_for_disputes_input
        card.find(".city-for-disputes-input input")
      end

      def save_button
        card.find(".btn-primary.save-card")
      end

      def has_saved_successfully?
        card.has_css?(".successful-save-alert")
      end

      def card
        find(".admin-config-area-card.your-organization-section")
      end
    end
  end
end
