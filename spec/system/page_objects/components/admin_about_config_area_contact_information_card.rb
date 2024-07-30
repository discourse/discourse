# frozen_string_literal: true

module PageObjects
  module Components
    class AdminAboutConfigAreaContactInformationCard < PageObjects::Components::Base
      def community_owner_input
        form.field("communityOwner")
      end

      def contact_email_input
        form.field("contactEmail")
      end

      def contact_url_input
        form.field("contactURL")
      end

      def site_contact_user_selector
        PageObjects::Components::SelectKit.new(
          ".admin-config-area-about__contact-information-section .user-chooser",
        )
      end

      def site_contact_group_selector
        PageObjects::Components::SelectKit.new(
          ".admin-config-area-about__contact-information-section .group-chooser",
        )
      end

      def submit
        form.submit
      end

      def has_saved_successfully?
        PageObjects::Components::Toasts.new.has_success?(
          I18n.t("admin_js.admin.config_areas.about.toasts.contact_information_saved"),
        )
      end

      def form
        PageObjects::Components::FormKit.new(
          ".admin-config-area-about__contact-information-section .form-kit",
        )
      end
    end
  end
end
