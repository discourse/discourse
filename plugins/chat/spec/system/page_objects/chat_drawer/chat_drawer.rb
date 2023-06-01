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

      def back
        find("#{VISIBLE_DRAWER} .chat-drawer-header__back-btn").click
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
    end
  end
end
