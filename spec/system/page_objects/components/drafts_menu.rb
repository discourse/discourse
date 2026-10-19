# frozen_string_literal: true

module PageObjects
  module Components
    class DraftsMenu < PageObjects::Components::Base
      MENU_SELECTOR = ".topic-drafts-menu"

      def visible?
        have_count(0).does_not_match?(
          browser_root.locator(MENU_SELECTOR + "-trigger").filter(visible: true),
        )
      end

      def hidden?
        have_count(0).matches?(
          browser_root.locator(MENU_SELECTOR + "-trigger").filter(visible: true),
        )
      end

      def enabled?
        have_count(0).matches?(
          browser_root.locator(MENU_SELECTOR + "-trigger[disabled]").filter(visible: true),
        )
      end

      def disabled?
        have_count(0).does_not_match?(
          browser_root.locator(MENU_SELECTOR + "-trigger[disabled]").filter(visible: true),
        )
      end

      def open?
        have_count(0).does_not_match?(
          browser_root.locator(MENU_SELECTOR + "-content").filter(visible: true),
        )
      end

      def closed?
        have_count(0).matches?(
          browser_root.locator(MENU_SELECTOR + "-content").filter(visible: true),
        )
      end

      def has_view_all_link?
        have_count(0).does_not_match?(
          browser_root.locator(MENU_SELECTOR + "-content .view-all-drafts").filter(visible: true),
        )
      end

      def has_no_view_all_link?
        have_count(0).matches?(
          browser_root.locator(MENU_SELECTOR + "-content .view-all-drafts").filter(visible: true),
        )
      end

      def open
        browser_root.locator(MENU_SELECTOR + "-trigger").filter(visible: true).click
      end

      def resume_draft(index = 0)
        browser_root
          .locator(MENU_SELECTOR + "-content .topic-drafts-item button")
          .filter(visible: true)
          .tap { |elements| elements.first.wait_for(state: "visible") }
          .all[
          index
        ].click
      end

      def draft_item_count
        browser_root
          .locator(MENU_SELECTOR + "-content .topic-drafts-item")
          .filter(visible: true)
          .tap { |elements| elements.first.wait_for(state: "visible") }
          .all
          .size
      end

      def other_drafts_count
        browser_root
          .locator(MENU_SELECTOR + "-content .view-all-drafts span:first-child")
          .filter(visible: true)
          .get_attribute("data-other-drafts")
          .to_i
      end
    end
  end
end
