# frozen_string_literal: true

module PageObjects
  module Pages
    class ChatDrawer < PageObjects::Pages::Base
      VISIBLE_DRAWER = ".chat-drawer.is-expanded"

      def channel_index
        @channel_index ||= ::PageObjects::Components::Chat::ChannelIndex.new(VISIBLE_DRAWER)
      end

      def open_browse
        mouseout
        find("#{VISIBLE_DRAWER} .open-browse-page-btn").click
      end

      def close
        mouseout
        find("#{VISIBLE_DRAWER} .chat-drawer-header__close-btn").click
      end

      def back
        mouseout
        find("#{VISIBLE_DRAWER} .chat-drawer-header__back-btn").click
      end

      def open_channel(channel)
        channel_index.open_channel(channel)
        has_no_css?(".chat-skeleton")
      end

      def has_unread_channel?(channel)
        channel_index.has_unread_channel?(channel)
      end

      def has_no_unread_channel?(channel)
        channel_index.has_no_unread_channel?(channel)
      end

      def maximize
        mouseout
        find("#{VISIBLE_DRAWER} .chat-drawer-header__full-screen-btn").click
      end

      def has_open_thread?(thread = nil)
        if thread
          has_css?("#{VISIBLE_DRAWER} .chat-thread[data-id='#{thread.id}']")
        else
          has_css?("#{VISIBLE_DRAWER} .chat-thread")
        end
      end

      def has_open_channel?(channel)
        has_css?("#{VISIBLE_DRAWER} .chat-channel[data-id='#{channel.id}']")
      end

      def has_open_thread_list?
        has_css?("#{VISIBLE_DRAWER} .chat-thread-list")
      end

      def open_thread_list
        find(thread_list_button_selector).click
      end

      def thread_list_button_selector
        ".chat-threads-list-button"
      end

      def has_unread_thread_indicator?(count:)
        has_css?("#{thread_list_button_selector}.has-unreads") &&
          has_css?(
            ".chat-thread-header-unread-indicator .chat-thread-header-unread-indicator__number",
            text: count.to_s,
          )
      end

      def has_no_unread_thread_indicator?
        has_no_css?("#{thread_list_button_selector}.has-unreads")
      end

      private

      def mouseout
        # Ensure that the mouse is not hovering over the drawer
        # and that the message actions menu is closed.
        # This check is essential because the message actions menu might partially
        # overlap with the header, making certain buttons inaccessible.
        find("#site-logo").hover
      end
    end
  end
end
