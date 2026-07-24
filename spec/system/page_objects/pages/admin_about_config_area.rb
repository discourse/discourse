# frozen_string_literal: true

module PageObjects
  module Pages
    class AdminAboutConfigArea < PageObjects::Pages::Base
      def visit
        page.visit("/admin/config/about")
      end

      def select_locale(locale)
        find(
          ".admin-config-area-about__locale-selector-dropdown option[value='#{locale}']",
        ).select_option
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

      def has_no_group_listing_section?
        has_no_css?(".admin-config-area-about__extra-groups-section")
      end

      def has_no_contact_information_section?
        has_no_css?(".admin-config-area-about__contact-information-section")
      end

      def has_no_your_organization_section?
        has_no_css?(".admin-config-area-about__your-organization-section")
      end

      def has_language_toolbar?
        has_css?(".admin-config-area__primary-content > .admin-config-area-about__language-toolbar")
      end

      def has_no_language_toolbar?
        has_no_css?(".admin-config-area-about__language-toolbar")
      end

      def has_locale_description?
        has_css?(
          ".admin-config-area-about__locale-selector .form-kit__container-help-text",
          text: "Only translatable About page fields are shown.",
        )
      end
    end
  end
end
