# frozen_string_literal: true

module PageObjects
  module Pages
    class ChatSidebar < PageObjects::Pages::Base
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
        menu = open_channel_hover_menu(channel)
        menu.option(".chat-channel-sidebar-link-menu__leave-channel").click
      end

      def open_channel_settings(channel)
        menu = open_channel_hover_menu(channel)
        menu.option(".chat-channel-sidebar-link-menu__channel-settings").click
      end

      def channel_section_link_selector(channel)
        ".sidebar-section-link.channel-#{channel.id}"
      end

      def open_channel_hover_menu(channel)
        find(channel_section_link_selector(channel)).hover
        first_level_hover_menu =
          PageObjects::Components::DMenu.new(
            "#{channel_section_link_selector(channel)} .sidebar-section-hover-button",
            (
              if channel.direct_message_channel?
                "chat-direct-message-channel-menu"
              else
                "chat-channel-menu"
              end
            ),
          )
        first_level_hover_menu.expand
        first_level_hover_menu
      end

      def find_channel(channel)
        find(".sidebar-section-link.channel-#{channel.id}")
        self
      end

      def has_no_channel?(channel)
        has_no_css?(".sidebar-row.channel-#{channel.id}")
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

      def open_notification_settings(channel)
        menu = open_channel_hover_menu(channel)
        notification_button =
          menu.option(".chat-channel-sidebar-link-menu__open-notification-settings")
        notification_button.click

        PageObjects::Components::DMenu.new(
          notification_button,
          "chat-channel-menu-notification-submenu",
        )
      end

      # Requires open_notification_settings to be called first
      def set_notification_level(level)
        find(".chat-channel-sidebar-link-menu__notification-level-#{level}").click
        self
      end

      # Requires open_notification_settings to be called first
      def toggle_mute_channel
        find(".chat-channel-sidebar-link-menu__mute-channel").click
        self
      end
    end
  end
end
