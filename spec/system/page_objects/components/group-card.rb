# frozen_string_literal: true

module PageObjects
  module Components
    class GroupCard < PageObjects::Components::Base
      MAX_MEMBER_HIGHLIGHT_COUNT = 10
      JOIN_BUTTON_SELECTOR = ".group-details-button .group-index-join"
      LEAVE_BUTTON_SELECTOR = ".group-details-button .group-index-leave"

      def click_join_button
        find(JOIN_BUTTON_SELECTOR).click
      end

      def click_leave_button
        find(LEAVE_BUTTON_SELECTOR).click
      end

      def has_highlighted_member_count_of?(expected_count)
        all(".card-content .members.metadata a.card-tiny-avatar", count: expected_count)
      end

      def has_join_button?
        has_css?(JOIN_BUTTON_SELECTOR)
      end

      def has_leave_button?
        has_css?(LEAVE_BUTTON_SELECTOR)
      end
    end
  end
end
