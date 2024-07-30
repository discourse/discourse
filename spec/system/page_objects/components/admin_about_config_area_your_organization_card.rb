# frozen_string_literal: true

module PageObjects
  module Components
    class AdminAboutConfigAreaYourOrganizationCard < PageObjects::Components::Base
      def company_name_input
        form.field("companyName")
      end

      def governing_law_input
        form.field("governingLaw")
      end

      def city_for_disputes_input
        form.field("cityForDisputes")
      end

      def submit
        form.submit
      end

      def has_saved_successfully?
        PageObjects::Components::Toasts.new.has_success?(
          I18n.t("admin_js.admin.config_areas.about.toasts.your_organization_saved"),
        )
      end

      def form
        PageObjects::Components::FormKit.new(
          ".admin-config-area-about__your-organization-section .form-kit",
        )
      end
    end
  end
end
