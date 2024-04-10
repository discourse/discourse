# frozen_string_literal: true
module PageObjects
  module Modals
    class TopicBulkActions < PageObjects::Modals::Base
      MODAL_SELECTOR = ".topic-bulk-actions-modal"

      def tag_selector
        Components::SelectKit.new(".tag-chooser")
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
    end
  end
end
