# frozen_string_literal: true

module PageObjects
  module Components
    class AdminAboutConfigAreaContactInformationCard < PageObjects::Components::Base
      def community_owner_input
        card.find(".community-owner-input input")
      end

      def contact_email_input
        card.find(".contact-email-input input")
      end

      def contact_url_input
        card.find(".contact-url-input input")
      end

      def site_contact_user_selector
        PageObjects::Components::SelectKit.new(
          ".admin-config-area-about__contact-information-section .site-contact-username-input .user-chooser",
        )
      end

      def site_contact_group_selector
        PageObjects::Components::SelectKit.new(
          ".admin-config-area-about__contact-information-section .site-contact-group-input .group-chooser",
        )
      end

      def save_button
        card.find(".btn-primary.admin-config-area-card__btn-save")
      end

      def has_saved_successfully?
        PageObjects::Components::Toasts.new.has_success?(
          I18n.t("admin_js.admin.config_areas.about.toasts.contact_information_saved"),
        )
      end

      def card
        find(".admin-config-area-about__contact-information-section")
      end
    end
  end
end
