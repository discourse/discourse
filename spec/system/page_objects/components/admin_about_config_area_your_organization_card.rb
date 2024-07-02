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
        card.find(".btn-primary.admin-config-area-card__btn-save")
      end

      def has_saved_successfully?
        PageObjects::Components::Toasts.new.has_success?(
          I18n.t("admin_js.admin.config_areas.about.toasts.your_organization_saved"),
        )
      end

      def card
        find(".admin-config-area-about__your-organization-section")
      end
    end
  end
end
