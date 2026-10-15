# frozen_string_literal: true

module PageObjects
  module Components
    class TopicListHeader < PageObjects::Components::Base
      TOPIC_LIST_HEADER_SELECTOR = ".topic-list .topic-list-header"
      TOPIC_LIST_DATA_SELECTOR = "#{TOPIC_LIST_HEADER_SELECTOR} .topic-list-data"

      def topic_list_header
        TOPIC_LIST_HEADER_SELECTOR
      end

      def has_bulk_select_button?
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root.locator(".bulk-select").filter(visible: true),
        )
      end

      def click_bulk_select_button
        browser_root.locator(".bulk-select").filter(visible: true).click
      end

      def has_bulk_select_topics_dropdown?
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root.locator(
            "#{TOPIC_LIST_HEADER_SELECTOR} .bulk-select-topics .bulk-select-topics-dropdown",
          ).filter(visible: true),
        )
      end

      def click_bulk_select_topics_dropdown
        browser_root
          .locator("#{TOPIC_LIST_HEADER_SELECTOR} .bulk-select-topics .bulk-select-topics-dropdown")
          .filter(visible: true)
          .click
      end

      def click_bulk_button(name)
        browser_root.locator(bulk_select_dropdown_item(name)).filter(visible: true).click
      end

      def has_bulk_select_modal?
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root.locator("#discourse-modal-title").filter(visible: true),
        )
      end

      def click_bulk_topics_confirm
        browser_root.locator("#bulk-topics-confirm").filter(visible: true).click
      end

      def click_silent
        browser_root.locator("#topic-bulk-action-options__silent").filter(visible: true).click
      end

      def fill_in_close_note(message)
        browser_root.locator("#bulk-close-note").filter(visible: true).fill(message)
      end

      def click_dismiss_read_confirm
        browser_root.locator("#dismiss-read-confirm").filter(visible: true).click
      end

      def click_sort_by(order)
        browser_root
          .locator("#{TOPIC_LIST_HEADER_SELECTOR} th[data-sort-order='#{order}']")
          .filter(visible: true)
          .click
      end

      private

      def bulk_select_dropdown_item(name)
        ".bulk-select-topics-dropdown-content li.dropdown-menu__item .btn.#{name}"
      end
    end
  end
end
