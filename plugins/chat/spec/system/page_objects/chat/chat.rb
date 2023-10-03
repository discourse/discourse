# frozen_string_literal: true

module PageObjects
  module Pages
    class Chat < PageObjects::Pages::Base
      def message_creator
        @message_creator ||= PageObjects::Components::Chat::MessageCreator.new
      end

      def sidebar
        @sidebar ||= PageObjects::Components::Chat::Sidebar.new
      end

      def prefers_full_page
        page.execute_script(
          "window.localStorage.setItem('discourse_chat_preferred_mode', '\"FULL_PAGE_CHAT\"');",
        )
      end

      def prefers_drawer
        page.execute_script(
          "window.localStorage.setItem('discourse_chat_preferred_mode', '\"DRAWER_CHAT\"');",
        )
      end

      def open_from_header
        find(".chat-header-icon").click
      end

      def has_header_href?(href)
        find(".chat-header-icon").has_link?(href: href)
      end

      def open
        visit("/chat")
      end

      def open_new_message(ensure_open: true)
        send_keys([PLATFORM_KEY_MODIFIER, "k"])
        find(".chat-modal-new-message") if ensure_open
      end

      def has_drawer?(channel_id: nil, expanded: true)
        drawer?(expectation: true, channel_id: channel_id, expanded: expanded)
      end

      def has_no_drawer?(channel_id: nil, expanded: true)
        drawer?(expectation: false, channel_id: channel_id, expanded: expanded)
      end

      def visit_channel(channel, message_id: nil)
        visit(channel.url + (message_id ? "/#{message_id}" : ""))
        has_no_css?(".chat-channel--not-loaded-once")
        has_no_css?(".chat-skeleton")
      end

      def visit_thread(thread)
        visit(thread.url)
        has_css?(".chat-thread:not(.loading)[data-id=\"#{thread.id}\"]")
      end

      def visit_channel_settings(channel)
        visit(channel.url + "/info/settings")
      end

      def visit_channel_about(channel)
        visit(channel.url + "/info/about")
      end

      def visit_channel_members(channel)
        visit(channel.url + "/info/members")
      end

      def visit_channel_info(channel)
        visit(channel.url + "/info")
      end

      def visit_browse(filter = nil)
        url = "/chat/browse"
        url += "/" + filter.to_s if filter
        visit(url)
        PageObjects::Pages::ChatBrowse.new.has_finished_loading?
      end

      def minimize_full_page
        find(".open-drawer-btn").click
      end

      NEW_CHANNEL_BUTTON_SELECTOR = ".new-channel-btn"

      def new_channel_button
        find(NEW_CHANNEL_BUTTON_SELECTOR)
      end

      def has_new_channel_button?
        has_css?(NEW_CHANNEL_BUTTON_SELECTOR)
      end

      def has_no_new_channel_button?
        has_no_css?(NEW_CHANNEL_BUTTON_SELECTOR)
      end

      private

      def drawer?(expectation:, channel_id: nil, expanded: true)
        selector = ".chat-drawer"
        selector += ".is-expanded" if expanded
        selector += "[data-chat-channel-id=\"#{channel_id}\"]" if channel_id
        expectation ? has_css?(selector) : has_no_css?(selector)
      end
    end
  end
end
