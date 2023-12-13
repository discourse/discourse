# frozen_string_literal: true

module PageObjects
  module Pages
    class UserThreads < PageObjects::Pages::Base
      def has_threads?(count: nil)
        has_no_css?(".spinner")
        has_css?(".dcp-user-thread", count: count)
      end

      def open_thread(thread)
        find(".dcp-user-thread[data-id='#{thread.id}'] .chat__thread-title__name").click
      end
    end
  end
end
