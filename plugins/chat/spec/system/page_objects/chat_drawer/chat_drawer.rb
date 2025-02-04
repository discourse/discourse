# frozen_string_literal: true

module PageObjects
  module Pages
    class ChatDrawer < PageObjects::Pages::Base
      VISIBLE_DRAWER = ".chat-drawer.is-expanded"

      def channels_index
        @channels_index ||= ::PageObjects::Components::Chat::ChannelsIndex.new(VISIBLE_DRAWER)
      end

      def browse
        @browse ||= ::PageObjects::Pages::ChatBrowse.new(".c-drawer-routes.--browse")
      end

      def open_browse
        mouseout
        find("#{VISIBLE_DRAWER} .open-browse-page-btn").click
      end

      def close
        mouseout
        find("#{VISIBLE_DRAWER} .c-navbar__close-drawer-button").click
      end

      def back
        mouseout
        find("#{VISIBLE_DRAWER} .c-navbar__back-button").click
      end

      def visit_index
        visit("/")
        PageObjects::Pages::Chat.new.open_from_header
      end

      def visit_channel(channel)
        visit_index
        open_channel(channel)
      end

      def visit_browse
        visit_index
        open_browse
      end

      def open_channel(channel)
        channels_index.open_channel(channel)
        has_no_css?(".chat-skeleton")
      end

      def has_channel?(channel)
        channels_index.has_channel?(channel)
      end

      def has_no_channel?(channel)
        channels_index.has_no_channel?(channel)
      end

      def has_channel_at_position?(channel, position)
        find(
          "#{VISIBLE_DRAWER} .chat-channel-row:nth-child(#{position})[data-chat-channel-id='#{channel.id}']",
        )
      end

      def has_unread_channel?(channel)
        channels_index.has_unread_channel?(channel)
      end

      def has_no_unread_channel?(channel)
        channels_index.has_no_unread_channel?(channel)
      end

      def has_urgent_channel?(channel)
        channels_index.has_unread_channel?(channel, urgent: true)
      end

      def has_user_threads_section?
        has_css?("#c-footer-threads")
      end

      def has_no_user_threads_section?
        has_no_css?("#c-footer-threads")
      end

      def has_unread_user_threads?
        has_css?(".chat-channel-row.--threads .c-unread-indicator")
      end

      def has_no_unread_user_threads?
        has_no_css?(".chat-channel-row.--threads .c-unread-indicator")
      end

      def click_channels
        find("#c-footer-channels").click
      end

      def click_direct_messages
        find("#c-footer-direct-messages").click
      end

      def click_user_threads
        find("#c-footer-threads").click
      end

      def maximize
        mouseout
        find("#{VISIBLE_DRAWER} .c-navbar__full-page-button").click
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

      def has_channel_settings?
        has_css?("#{VISIBLE_DRAWER} .c-channel-settings")
      end

      def has_channel_members?
        has_css?("#{VISIBLE_DRAWER} .c-channel-members")
      end

      def has_open_channels?
        has_css?("#{VISIBLE_DRAWER} .public-channels")
      end

      def has_open_direct_messages?
        has_css?("#{VISIBLE_DRAWER} .direct-message-channels")
      end

      def has_open_user_threads?
        has_css?("#{VISIBLE_DRAWER} .c-user-threads")
      end

      def has_open_thread_list?
        has_css?("#{VISIBLE_DRAWER} .chat-thread-list")
      end

      def open_thread_list
        find(thread_list_button_selector).click
      end

      def thread_list_button_selector
        ".c-navbar__threads-list-button"
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

      def has_direct_message_channels_section?
        has_css?(".direct-message-channels-section")
      end

      private

      def mouseout
        # Ensure that the mouse is not hovering over the drawer
        # and that the message actions menu is closed.
        # This check is essential because the message actions menu might partially
        # overlap with the header, making certain buttons inaccessible.
        PageObjects::Components::Logo.hover
      end
    end
  end
end
