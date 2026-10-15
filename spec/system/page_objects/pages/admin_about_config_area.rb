# frozen_string_literal: true

module PageObjects
  module Pages
    class AdminAboutConfigArea < PageObjects::Pages::Base
      def visit
        browser_page
          .goto("/admin/config/about")
          .tap { SystemBrowserBootstrap.wait_for(browser_page) }
      end

      def select_locale(locale)
        browser_root.locator(".admin-config-area-about__locale-selector-dropdown").select_option(
          value: locale,
        )
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
        PlaywrightMatchers.have_count(0).matches?(
          browser_root.locator(".admin-config-area-about__extra-groups-section").filter(
            visible: true,
          ),
        )
      end

      def has_no_contact_information_section?
        PlaywrightMatchers.have_count(0).matches?(
          browser_root.locator(".admin-config-area-about__contact-information-section").filter(
            visible: true,
          ),
        )
      end

      def has_no_your_organization_section?
        PlaywrightMatchers.have_count(0).matches?(
          browser_root.locator(".admin-config-area-about__your-organization-section").filter(
            visible: true,
          ),
        )
      end

      def has_language_toolbar?
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root.locator(
            ".admin-config-area__primary-content > .admin-config-area-about__language-toolbar",
          ).filter(visible: true),
        )
      end

      def has_no_language_toolbar?
        PlaywrightMatchers.have_count(0).matches?(
          browser_root.locator(".admin-config-area-about__language-toolbar").filter(visible: true),
        )
      end

      def has_locale_description?
        PlaywrightMatchers.contain_text(
          [browser_text_pattern("Only translatable About page fields are shown.")],
          useInnerText: true,
        ).matches?(
          browser_root.locator(
            ".admin-config-area-about__locale-selector .form-kit__container-help-text",
          ).filter(visible: true),
        )
      end
    end
  end
end
