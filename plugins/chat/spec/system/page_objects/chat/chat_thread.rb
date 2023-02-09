# frozen_string_literal: true

module PageObjects
  module Pages
    class ChatThread < PageObjects::Pages::Base
      def has_header_content?(content)
        find(".chat-thread__header").has_content?(content)
      end
    end
  end
end
