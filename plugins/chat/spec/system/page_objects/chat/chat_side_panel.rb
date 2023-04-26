# frozen_string_literal: true

module PageObjects
  module Pages
    class ChatSidePanel < PageObjects::Pages::Base
      def has_open_thread?(thread)
        has_css?(".chat-side-panel .chat-thread[data-id='#{thread.id}']")
      end

      def has_no_open_thread?
        !has_css?(".chat-side-panel .chat-thread")
      end
    end
  end
end
