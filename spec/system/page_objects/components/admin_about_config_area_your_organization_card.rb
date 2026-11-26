# frozen_string_literal: true

module PageObjects
  module Components
    class AdminAboutConfigAreaYourOrganizationCard < PageObjects::Components::Base
      def company_name_input
        form.field("companyName")
      end

      def company_url_input
        form.field("companyURL")
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
