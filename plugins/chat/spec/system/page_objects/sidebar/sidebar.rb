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

      def open_draft_channel
        find(
          ".sidebar-section[data-section-name='chat-dms'] .sidebar-section-header-button",
          visible: false,
        ).click
      end

      def open_browse
        find(
          ".sidebar-section[data-section-name='chat-channels'] .sidebar-section-header-button",
          visible: false,
        ).click
      end

      def open_channel(channel)
        find(".sidebar-section-link[href='/chat/c/#{channel.slug}/#{channel.id}']").click
      end

      def find_channel(channel)
        find(".sidebar-section-link[href='/chat/c/#{channel.slug}/#{channel.id}']")
        self
      end
    end
  end
end
