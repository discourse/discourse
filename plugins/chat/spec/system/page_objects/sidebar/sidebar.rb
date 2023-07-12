# frozen_string_literal: true

module PageObjects
  module Pages
    class Sidebar < PageObjects::Pages::Base
      def channels_section
        find(".sidebar-section[data-section-name='chat-channels']")
      end

      def dms_section
        find(".sidebar-section[data-section-name='chat-dms']")
      end

      def open_browse
        find(
          ".sidebar-section[data-section-name='chat-channels'] .sidebar-section-header-button",
          visible: false,
        ).click
      end

      def open_channel(channel)
        find(".sidebar-section-link.channel-#{channel.id}").click
      end

      def remove_channel(channel)
        selector = ".sidebar-section-link.channel-#{channel.id}"
        find(selector).hover
        find(selector + " .sidebar-section-hover-button").click
      end

      def find_channel(channel)
        find(".sidebar-section-link.channel-#{channel.id}")
        self
      end
    end
  end
end
