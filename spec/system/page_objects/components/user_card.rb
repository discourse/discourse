# frozen_string_literal: true

module PageObjects
  module Components
    class UserCard < PageObjects::Components::Base
      USER_CARD_SELECTOR = ".user-card"
      FILTER_BUTTON_SELECTOR = "#{USER_CARD_SELECTOR} .usercard-controls .d-icon-filter"

      def visible?
        has_css?(USER_CARD_SELECTOR)
      end

      def showing_user?(username)
        has_css?("#{USER_CARD_SELECTOR}.user-card-#{username}")
      end

      def has_filter_button?
        has_css?(FILTER_BUTTON_SELECTOR)
      end

      def has_no_filter_button?
        has_no_css?(FILTER_BUTTON_SELECTOR)
      end

      def filter_button_text
        find("#{FILTER_BUTTON_SELECTOR} + .d-button-label").text
      end

      def click_filter_button
        find("#{FILTER_BUTTON_SELECTOR} + .d-button-label").click
      end

      def has_profile_hidden?
        has_css?("#{USER_CARD_SELECTOR} .profile-hidden", visible: true)
      end

      def has_inactive_user?
        has_css?("#{USER_CARD_SELECTOR} .inactive-user", visible: true)
      end
    end
  end
end
