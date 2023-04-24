# frozen_string_literal: true

module PageObjects
  module Pages
    class Chat < PageObjects::Pages::Base
      def prefers_full_page
        page.execute_script(
          "window.localStorage.setItem('discourse_chat_preferred_mode', '\"FULL_PAGE_CHAT\"');",
        )
      end

      def open_from_header
        find(".chat-header-icon").click
      end

      def open
        visit("/chat")
      end

      def visit_channel(channel, mobile: false)
        visit(channel.url + (mobile ? "?mobile_view=1" : ""))
        has_no_css?(".chat-channel--not-loaded-once")
        has_no_css?(".chat-skeleton")
      end

      def visit_thread(thread)
        visit(thread.url)
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

      def visit_browse
        visit("/chat/browse")
      end

      def minimize_full_page
        find(".open-drawer-btn").click
      end

      def has_message?(message)
        container = find(".chat-message-container[data-id=\"#{message.id}\"")
        container.has_content?(message.message)
        container.has_content?(message.user.username)
      end

      def new_channel_button
        find(".new-channel-btn")
      end

      def has_new_channel_button?
        has_css?(".new-channel-btn")
      end
    end
  end
end
