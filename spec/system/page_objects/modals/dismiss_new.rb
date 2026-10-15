# frozen_string_literal: true

module PageObjects
  module Modals
    class DismissNew < PageObjects::Modals::Base
      def has_dismiss_topics_checked?
        browser_root
          .locator(".dismiss-topics label")
          .filter(visible: true)
          .locator("input")
          .checked?
      end

      def has_dismiss_posts_checked?
        browser_root.locator(".dismiss-posts label").filter(visible: true).locator("input").checked?
      end

      def has_dismiss_topics_unchecked?
        browser_root
          .locator(".dismiss-topics label")
          .filter(visible: true)
          .locator("input")
          .checked? == false
      end

      def has_dismiss_posts_unchecked?
        browser_root
          .locator(".dismiss-posts label")
          .filter(visible: true)
          .locator("input")
          .checked? == false
      end

      def has_untrack_unchecked?
        browser_root.locator(".untrack label").filter(visible: true).locator("input").checked? ==
          false
      end

      def click_dismiss
        browser_root
          .locator(
            "[id=#{"dismiss-read-confirm".to_s.to_json}], [name=#{"dismiss-read-confirm".to_s.to_json}]",
          )
          .or(browser_root.get_by_role("button", name: "dismiss-read-confirm"))
          .filter(visible: true)
          .click
        self
      end

      def closed?
        PlaywrightMatchers.have_count(0).matches?(
          browser_root.locator(".d-modal").filter(visible: true),
        )
      end
    end
  end
end
