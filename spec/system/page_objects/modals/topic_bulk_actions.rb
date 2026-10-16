# frozen_string_literal: true
module PageObjects
  module Modals
    class TopicBulkActions < PageObjects::Modals::Base
      MODAL_SELECTOR = ".topic-bulk-actions-modal"

      def category_selector
        PageObjects::Components::SelectKit.new(".category-chooser")
      end

      def click_bulk_topics_confirm
        browser_root.locator("#bulk-topics-confirm").filter(visible: true).click
      end

      def click_dismiss_confirm
        browser_root.locator("#dismiss-read-confirm").filter(visible: true).click
      end

      def fill_in_close_note(message)
        browser_root.locator("#bulk-close-note").filter(visible: true).fill(message)
      end

      def select_notification_level(level)
        browser_root
          .locator(".bulk-notification-list input[name='notification_level'][value='#{level}']")
          .filter(visible: true)
          .click
      end

      def has_category_badge?(category)
        within_browser(MODAL_SELECTOR) do
          PageObjects::Components::CategoryBadge.new.find_for_category(category)
        end
      end

      def pin_in_category_date_selector
        PageObjects::Components::SelectKit.new(
          "#{MODAL_SELECTOR} .feature-section:first-of-type .future-date-input-selector",
        )
      end

      def click_pin_in_category
        browser_root
          .locator("#{MODAL_SELECTOR} .feature-section:first-of-type .btn-primary")
          .filter(visible: true)
          .click
      end

      def pin_globally_date_selector
        PageObjects::Components::SelectKit.new(
          "#{MODAL_SELECTOR} .feature-section:last-of-type .future-date-input-selector",
        )
      end

      def click_pin_globally
        browser_root
          .locator("#{MODAL_SELECTOR} .feature-section:last-of-type .btn-primary")
          .filter(visible: true)
          .click
      end

      def has_pin_stats_text?(text)
        contain_text([text], useInnerText: true).matches?(
          browser_page.locator("#{MODAL_SELECTOR} .feature-section").filter(visible: true),
        )
      end

      def has_no_category_badge?(category)
        within_browser(MODAL_SELECTOR) do
          have_count(0).matches?(
            browser_root.locator(
              PageObjects::Components::CategoryBadge.new.category_selector(category),
            ).filter(visible: true),
          )
        end
      end

      def has_errors?(text = nil)
        if text
          contain_text([browser_text_pattern(text)], useInnerText: true).matches?(
            browser_root.locator("#{MODAL_SELECTOR}__errors").filter(visible: true),
          )
        else
          have_count(0).does_not_match?(
            browser_root.locator("#{MODAL_SELECTOR}__errors").filter(visible: true),
          )
        end
      end
    end
  end
end
