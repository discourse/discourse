# frozen_string_literal: true

module PageObjects
  module Pages
    class ChatChannelThreads < PageObjects::Pages::Base
      def close
        find(".c-routes.--channel-threads .c-navbar__close-threads-button").click
      end

      def back
        find(".c-routes.--channel-threads .c-navbar__back-button").click
      end
    end
  end
end
