# frozen_string_literal: true

module PageObjects
  module Components
    class LiveBackToLiveRoom < PageObjects::Components::Base
      SELECTOR = ".c-navbar__back-to-live-room"

      def has_back_to_room_button?
        has_css?(SELECTOR)
      end

      def has_no_back_to_room_button?
        has_no_css?(SELECTOR)
      end

      def click
        find(SELECTOR).click
        self
      end
    end
  end
end
