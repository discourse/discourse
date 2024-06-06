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
          ".contact-information-section .site-contact-username-input .user-chooser",
        )
      end

      def site_contact_group_selector
        PageObjects::Components::SelectKit.new(
          ".contact-information-section .site-contact-group-input .group-chooser",
        )
      end

      def save_button
        card.find(".btn-primary.save-card")
      end

      def has_saved_successfully?
        card.has_css?(".successful-save-alert")
      end

      def card
        find(".admin-config-area-card.contact-information-section")
      end
    end
  end
end
