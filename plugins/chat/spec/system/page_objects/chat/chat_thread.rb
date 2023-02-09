# frozen_string_literal: true

module PageObjects
  module Pages
    class ChatThread < PageObjects::Pages::Base
      def header
        find(".chat-thread__header")
      end

      def omu
        header.find(".chat-thread__omu")
      end

      def has_header_content?(content)
        header.has_content?(content)
      end
    end
  end
end
