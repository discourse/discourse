# frozen_string_literal: true

module PageObjects
  module Pages
    class Sidebar < PageObjects::Pages::Base
      PUBLIC_CHANNELS_SECTION_SELECTOR = ".sidebar-section[data-section-name='chat-channels']"
      DM_CHANNELS_SECTION_SELECTOR = ".sidebar-section[data-section-name='chat-dms']"

      def has_no_public_channels_section?
        has_no_css?(PUBLIC_CHANNELS_SECTION_SELECTOR)
      end

      def channels_section
        find(PUBLIC_CHANNELS_SECTION_SELECTOR)
      end

      def dms_section
        find(DM_CHANNELS_SECTION_SELECTOR)
      end

      def open_browse
        channels_section.find(".sidebar-section-header-button", visible: false).click
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

      def has_user_threads_section?
        has_css?(
          ".sidebar-section-link[data-link-name='user-threads'][href='/chat/threads']",
          text: I18n.t("js.chat.my_threads.title"),
        )
      end

      def has_no_user_threads_section?
        has_no_css?(
          ".sidebar-section-link[data-link-name='user-threads'][href='/chat/threads']",
          text: I18n.t("js.chat.my_threads.title"),
        )
      end

      def has_unread_user_threads?
        has_css?(
          ".sidebar-section-link[data-link-name='user-threads'] .sidebar-section-link-suffix.icon.unread",
        )
      end

      def has_no_unread_user_threads?
        has_no_css?(
          ".sidebar-section-link[data-link-name='user-threads'] .sidebar-section-link-suffix.icon.unread",
        )
      end

      def has_unread_channel?(channel)
        has_css?(
          ".sidebar-section-link.channel-#{channel.id} .sidebar-section-link-suffix:is(.unread, .urgent)",
        )
      end

      def has_no_unread_channel?(channel)
        has_no_css?(
          ".sidebar-section-link.channel-#{channel.id} .sidebar-section-link-suffix:is(.unread, .urgent)",
        )
      end

      def has_active_channel?(channel)
        has_css?(".sidebar-section-link.channel-#{channel.id}.active")
      end

      def has_no_active_channel?(channel)
        has_no_css?(".sidebar-section-link.channel-#{channel.id}.active")
      end
    end
  end
end
