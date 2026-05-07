# frozen_string_literal: true
module PageObjects
  module Modals
    class TopicBulkActions < PageObjects::Modals::Base
      MODAL_SELECTOR = ".topic-bulk-actions-modal"

      def category_selector
        PageObjects::Components::SelectKit.new(".category-chooser")
      end

      def click_bulk_topics_confirm
        find("#bulk-topics-confirm").click
      end

      def click_dismiss_confirm
        find("#dismiss-read-confirm").click
      end

      def click_notify
        find("#topic-bulk-action-options__notify").click
      end

      def fill_in_close_note(message)
        find("#bulk-close-note").set(message)
      end

      def select_notification_level(level)
        find(".bulk-notification-list input[name='notification_level'][value='#{level}']").click
      end

      def has_category_badge?(category)
        within(MODAL_SELECTOR) do
          PageObjects::Components::CategoryBadge.new.find_for_category(category)
        end
      end

      def pin_in_category_date_selector
        PageObjects::Components::SelectKit.new(
          "#{MODAL_SELECTOR} .feature-section:first-of-type .future-date-input-selector",
        )
      end

      def click_pin_in_category
        find("#{MODAL_SELECTOR} .feature-section:first-of-type .btn-primary").click
      end

      def pin_globally_date_selector
        PageObjects::Components::SelectKit.new(
          "#{MODAL_SELECTOR} .feature-section:last-of-type .future-date-input-selector",
        )
      end

      def click_pin_globally
        find("#{MODAL_SELECTOR} .feature-section:last-of-type .btn-primary").click
      end

      def has_pin_stats_text?(text)
        page.has_css?("#{MODAL_SELECTOR} .feature-section", text: text, normalize_ws: true)
      end

      def has_no_category_badge?(category)
        within(MODAL_SELECTOR) do
          has_no_css?(PageObjects::Components::CategoryBadge.new.category_selector(category))
        end
      end

      def has_errors?(text = nil)
        if text
          has_css?("#{MODAL_SELECTOR}__errors", text: text)
        else
          has_css?("#{MODAL_SELECTOR}__errors")
        end
      end
    end
  end
end
