# frozen_string_literal: true

module PageObjects
  module Pages
    class ChatThreadList < PageObjects::Pages::Base
      def item_by_id(id)
        find(item_by_id_selector(id))
      end

      def item_by_id_selector(id)
        ".chat-thread-list__items .chat-thread-list-item[data-thread-id=\"#{id}\"]"
      end
    end
  end
end
