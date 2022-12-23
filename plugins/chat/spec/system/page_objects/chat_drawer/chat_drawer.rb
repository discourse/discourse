# frozen_string_literal: true

module PageObjects
  module Pages
    class ChatDrawer < PageObjects::Pages::Base
      VISIBLE_DRAWER = ".chat-drawer.is-expanded"
      def open_browse
        find("#{VISIBLE_DRAWER} .open-browse-page-btn").click
      end

      def open_draft_channel
        find("#{VISIBLE_DRAWER} .open-draft-channel-page-btn").click
      end

      def close
        find("#{VISIBLE_DRAWER} .chat-drawer-header__close-btn").click
      end

      def open_index
        find("#{VISIBLE_DRAWER} .chat-drawer-header__return-to-channels-btn").click
      end

      def open_channel(channel)
        find(
          "#{VISIBLE_DRAWER} .channels-list .chat-channel-row[data-chat-channel-id='#{channel.id}']",
        ).click
        has_no_css?(".chat-skeleton")
      end

      def maximize
        find("#{VISIBLE_DRAWER} .chat-drawer-header__full-screen-btn").click
      end
    end
  end
end
