# frozen_string_literal: true

module PageObjects
  module Components
    class UserCard < PageObjects::Components::Base
      USER_CARD_SELECTOR = ".user-card"
      FILTER_BUTTON_SELECTOR = "#{USER_CARD_SELECTOR} .usercard-controls .d-icon-filter"

      def visible?
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root.locator(USER_CARD_SELECTOR).filter(visible: true),
        )
      end

      def showing_user?(username)
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root.locator("#{USER_CARD_SELECTOR}.user-card-#{username}").filter(visible: true),
        )
      end

      def has_filter_button?
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root.locator(FILTER_BUTTON_SELECTOR).filter(visible: true),
        )
      end

      def has_no_filter_button?
        PlaywrightMatchers.have_count(0).matches?(
          browser_root.locator(FILTER_BUTTON_SELECTOR).filter(visible: true),
        )
      end

      def filter_button_text
        browser_root
          .locator("#{FILTER_BUTTON_SELECTOR} + .d-button-label")
          .filter(visible: true)
          .inner_text
          .strip
      end

      def click_filter_button
        browser_root
          .locator("#{FILTER_BUTTON_SELECTOR} + .d-button-label")
          .filter(visible: true)
          .click
      end

      def has_profile_hidden?
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root.locator("#{USER_CARD_SELECTOR} .profile-hidden").filter(visible: true),
        )
      end

      def has_inactive_user?
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root.locator("#{USER_CARD_SELECTOR} .inactive-user").filter(visible: true),
        )
      end

      def silence_reason_description
        browser_root
          .locator("#{USER_CARD_SELECTOR} .silence-reason .silence-reason-description")
          .filter(visible: true)
          .inner_text
          .strip
      end
    end
  end
end
