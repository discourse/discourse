# frozen_string_literal: true

module PageObjects
  module Pages
    class ChatThreadList < PageObjects::Pages::Base
      def item_by_id(id)
        find(item_by_id_selector(id))
      end

      def has_unread_item?(id)
        has_css?(item_by_id_selector(id) + ".-unread")
      end

      def has_no_unread_item?(id)
        has_no_css?(item_by_id_selector(id) + ".-unread")
      end

      def item_by_id_selector(id)
        ".chat-thread-list__items .chat-thread-list-item[data-thread-id=\"#{id}\"]"
      end
    end
  end
end
