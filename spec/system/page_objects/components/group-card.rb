# frozen_string_literal: true

module PageObjects
  module Components
    class GroupCard < PageObjects::Components::Base
      MAX_MEMBER_HIGHLIGHT_COUNT = 10
      JOIN_BUTTON_SELECTOR = ".group-details-button .group-index-join"
      LEAVE_BUTTON_SELECTOR = ".group-details-button .group-index-leave"

      def click_join_button
        browser_root.locator(JOIN_BUTTON_SELECTOR).filter(visible: true).click
      end

      def click_leave_button
        browser_root.locator(LEAVE_BUTTON_SELECTOR).filter(visible: true).click
      end

      def has_highlighted_member_count_of?(expected_count)
        browser_root
          .locator(".card-content .members.metadata a.card-tiny-avatar")
          .filter(visible: true)
          .tap { |elements| expect(elements).to PlaywrightMatchers.have_count(expected_count) }
          .all
      end

      def has_join_button?
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root.locator(JOIN_BUTTON_SELECTOR).filter(visible: true),
        )
      end

      def has_leave_button?
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root.locator(LEAVE_BUTTON_SELECTOR).filter(visible: true),
        )
      end
    end
  end
end
