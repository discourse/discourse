# frozen_string_literal: true

module PageObjects
  module Components
    class TopicListHeader < PageObjects::Components::Base
      TOPIC_LIST_HEADER_SELECTOR = ".topic-list .topic-list-header"
      TOPIC_LIST_DATA_SELECTOR = "#{TOPIC_LIST_HEADER_SELECTOR} .topic-list-data".freeze

      def topic_list_header
        TOPIC_LIST_HEADER_SELECTOR
      end

      def has_bulk_select_button?
        page.has_css?(".bulk-select")
      end

      def click_bulk_select_button
        find(".bulk-select").click
      end

      def has_bulk_select_topics_dropdown?
        page.has_css?(
          "#{TOPIC_LIST_HEADER_SELECTOR} .bulk-select-topics .bulk-select-topics-dropdown",
        )
      end

      def click_bulk_select_topics_dropdown
        find("#{TOPIC_LIST_HEADER_SELECTOR} .bulk-select-topics .bulk-select-topics-dropdown").click
      end

      def click_bulk_button(name)
        find(bulk_select_dropdown_item(name)).click
      end

      def has_bulk_select_modal?
        page.has_css?("#discourse-modal-title")
      end

      def click_bulk_topics_confirm
        find("#bulk-topics-confirm").click
      end

      def click_silent
        find("#topic-bulk-action-options__silent").click
      end

      def fill_in_close_note(message)
        find("#bulk-close-note").set(message)
      end

      def click_dismiss_read_confirm
        find("#dismiss-read-confirm").click
      end
      ### /TODO

      private

      def bulk_select_dropdown_item(name)
        ".bulk-select-topics-dropdown-content li.dropdown-menu__item .btn.#{name}"
      end
    end
  end
end
