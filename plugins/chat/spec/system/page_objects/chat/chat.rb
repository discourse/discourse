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

      def footer
        @footer ||= PageObjects::Components::Chat::Footer.new
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
        has_css?("html.has-chat")
      end

      def close_from_header
        find(".chat-header-icon").click
        has_no_css?("html.has-chat")
      end

      def back_to_channels_list
        find(".d-icon.d-icon-chevron-left").click
        has_css?("html.has-chat")
      end

      def has_header_href?(href)
        find(".chat-header-icon").has_link?(href: href)
      end

      def open(with_preloaded_channels: true)
        visit("/chat")
        has_finished_loading?(with_preloaded_channels: with_preloaded_channels)
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

      def visit_channel(channel, message_id: nil, with_preloaded_channels: true, check: true)
        visit(channel.url + (message_id ? "/#{message_id}" : ""))
        has_finished_loading?(with_preloaded_channels: with_preloaded_channels) if check
      end

      def visit_user_threads
        visit("/chat/threads")
        has_css?(".c-user-threads.--loaded")
      end

      def visit_thread(thread)
        visit(thread.url)
        has_css?(".chat-thread.--loaded[data-id=\"#{thread.id}\"]")
      end

      def visit_threads_list(channel)
        visit(channel.url + "/t")
        has_finished_loading?
      end

      def visit_channel_settings(channel)
        visit(channel.url + "/info/settings")
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

      def visit_new_message(recipients)
        if recipients.is_a?(Array)
          recipients = recipients.map(&:username).join(",")
        elsif recipients.respond_to?(:username)
          recipients = recipients.username
        end

        visit("/chat/new-message?recipients=#{recipients}")
      end

      def has_preloaded_channels?
        has_css?("body.has-preloaded-chat-channels")
      end

      def has_finished_loading?(with_preloaded_channels: true)
        has_preloaded_channels? if with_preloaded_channels
        has_css?(".--loaded")
        has_no_css?(".chat-skeleton")
      end

      def minimize_full_page
        find(".c-navbar__open-drawer-button").click
      end

      NEW_CHANNEL_BUTTON_SELECTOR = ".c-navbar__new-channel-button"

      def new_channel_button
        find(NEW_CHANNEL_BUTTON_SELECTOR)
      end

      def has_new_channel_button?
        has_css?(NEW_CHANNEL_BUTTON_SELECTOR)
      end

      def has_no_new_channel_button?
        has_no_css?(NEW_CHANNEL_BUTTON_SELECTOR)
      end

      def has_no_messages?
        have_selector(".empty-state")
      end

      def has_direct_message_channels_section?
        has_css?(".direct-message-channels-section")
      end

      def has_add_member_button?
        has_css?(".c-channel-members__list-item.-add-member")
      end

      def has_no_add_member_button?
        has_no_css?(".c-channel-members__list-item.-add-member")
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
