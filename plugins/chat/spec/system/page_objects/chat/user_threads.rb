# frozen_string_literal: true

module PageObjects
  module Pages
    class UserThreads < PageObjects::Pages::Base
      def has_threads?(count: nil)
        has_no_css?(".spinner")
        has_css?(".c-user-thread", count: count)
      end

      def open_thread(thread)
        find(".c-user-thread[data-id='#{thread.id}'] .chat__thread-title__name").click
      end

      def excerpt_text
        find(".c-user-thread__excerpt-text").text
      end
    end
  end
end
