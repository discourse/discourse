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
        find(".sidebar-section-link[href='/chat/c/#{channel.slug}/#{channel.id}']").click
      end

      def find_channel(channel)
        find(".sidebar-section-link[href='/chat/c/#{channel.slug}/#{channel.id}']")
        self
      end

      def has_unread_channel?(channel)
        has_css?(".sidebar-section-link.channel-#{channel.id} .sidebar-section-link-suffix.unread")
      end

      def has_no_unread_channel?(channel)
        has_no_css?(
          ".sidebar-section-link.channel-#{channel.id} .sidebar-section-link-suffix.unread",
        )
      end
    end
  end
end
