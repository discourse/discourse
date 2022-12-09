# frozen_string_literal: true

module PageObjects
  module Pages
    class Chat < PageObjects::Pages::Base
      def open_from_header
        find(".open-chat").click
      end

      def open
        visit("/chat")
      end

      def visit_channel(channel)
        visit(channel.url)
      end

      def minimize_full_page
        find(".open-drawer-btn").click
      end
    end
  end
end
