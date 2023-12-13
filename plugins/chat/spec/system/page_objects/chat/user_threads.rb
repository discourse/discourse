# frozen_string_literal: true

module PageObjects
  module Pages
    class UserThreads < PageObjects::Pages::Base
      def has_threads?(count: nil)
        has_no_css?(".spinner")
        has_css?(".chat__user-threads__thread-container", count: count)
      end

      def open_thread(thread)
        find(
          ".chat__user-threads__thread-container[data-id='#{thread.id}'] .chat__thread-title__name",
        ).click
      end
    end
  end
end
