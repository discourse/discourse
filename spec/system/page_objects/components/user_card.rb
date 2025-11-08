# frozen_string_literal: true

module PageObjects
  module Components
    class UserCard < PageObjects::Components::Base
      def visible?
        has_css?("#user-card")
      end

      def showing_user?(username)
        has_css?("#user-card.user-card-#{username}")
      end

      def has_filter_button?
        has_css?("#user-card .usercard-controls .d-icon-filter")
      end

      def has_no_filter_button?
        has_no_css?("#user-card .usercard-controls .d-icon-filter")
      end

      def filter_button_text
        find("#user-card .usercard-controls .d-icon-filter + .d-button-label").text
      end

      def has_profile_hidden?
        has_css?("#user-card .profile-hidden")
      end
    end
  end
end
