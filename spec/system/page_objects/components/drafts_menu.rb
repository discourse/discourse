# frozen_string_literal: true

module PageObjects
  module Components
    class DraftsMenu < PageObjects::Components::Base
      MENU_SELECTOR = ".topic-drafts-menu"

      def visible?
        has_css?(MENU_SELECTOR + "-trigger")
      end

      def hidden?
        has_no_css?(MENU_SELECTOR + "-trigger")
      end

      def open?
        has_css?(MENU_SELECTOR + "-content")
      end

      def closed?
        has_no_css?(MENU_SELECTOR + "-content")
      end

      def open
        find(MENU_SELECTOR + "-trigger").click
      end

      def draft_item_count
        all(MENU_SELECTOR + "-content .topic-drafts-item").size
      end

      def other_drafts_count
        find(MENU_SELECTOR + "-content .view-all-drafts span:first-child")["data-other-drafts"].to_i
      end
    end
  end
end
