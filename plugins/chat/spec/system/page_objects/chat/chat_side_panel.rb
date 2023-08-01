# frozen_string_literal: true

module PageObjects
  module Pages
    class ChatSidePanel < PageObjects::Pages::Base
      def open?
        has_css?(".chat-side-panel")
      end

      def closed?
        has_no_css?(".chat-side-panel")
      end

      def has_open_thread?(thread = nil)
        if thread
          has_css?(".chat-side-panel .chat-thread[data-id='#{thread.id}']")
        else
          has_css?(".chat-side-panel .chat-thread")
        end
        PageObjects::Pages::ChatThread.new.has_no_loading_skeleton?
      end

      def has_no_open_thread?
        has_no_css?(".chat-side-panel .chat-thread")
      end

      def has_open_thread_list?
        has_css?(".chat-side-panel .chat-thread-list")
      end
    end
  end
end
