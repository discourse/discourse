# frozen_string_literal: true

module PageObjects
  module Pages
    class Chat < PageObjects::Pages::Base
      def open_from_header
        find(".open-chat").click
      end

      def open_full_page
        visit("/chat")
      end

      def maximize_drawer
        find(".topic-chat-drawer-header__full-screen-btn").click
      end

      def minimize_full_page
        find(".chat-full-screen-button").click
      end
    end
  end
end
