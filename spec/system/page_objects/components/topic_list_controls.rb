# frozen_string_literal: true

module PageObjects
  module Components
    class TopicListControls < PageObjects::Components::Base
      def has_new?(count:)
        text =
          if count == 0
            I18n.t("js.filters.new.title")
          else
            I18n.t("js.filters.new.title_with_count", count: count)
          end

        contain_text([browser_exact_text_pattern(text)], useInnerText: true).matches?(
          browser_root.locator(".nav-item_new").filter(visible: true),
        )
      end

      def dismiss_new
        browser_root
          .locator(
            "[id=#{"dismiss-new-top".to_s.to_json}], [name=#{"dismiss-new-top".to_s.to_json}]",
          )
          .or(browser_root.get_by_role("button", name: "dismiss-new-top"))
          .filter(visible: true)
          .click
        self
      end

      def dismiss_new_and_stop_tracking
        browser_root
          .locator(
            "[id=#{"dismiss-new-menu-top".to_s.to_json}], [name=#{"dismiss-new-menu-top".to_s.to_json}]",
          )
          .or(browser_root.get_by_role("button", name: "dismiss-new-menu-top"))
          .filter(visible: true)
          .click
        browser_root.locator(".dismiss-new-stop-tracking").filter(visible: true).click
        self
      end

      def click_latest
        browser_root.locator(".nav-item_latest").filter(visible: true).click
        self
      end
    end
  end
end
