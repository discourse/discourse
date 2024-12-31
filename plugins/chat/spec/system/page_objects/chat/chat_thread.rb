# frozen_string_literal: true

module PageObjects
  module Pages
    class ChatThread < PageObjects::Pages::Base
      def composer
        @composer ||= PageObjects::Components::Chat::Composer.new(".chat-thread")
      end

      def composer_message_details
        @composer_message_details ||=
          PageObjects::Components::Chat::ComposerMessageDetails.new(".chat-thread")
      end

      def messages
        @messages ||= PageObjects::Components::Chat::Messages.new(".chat-thread")
      end

      def header
        @header ||= PageObjects::Components::Chat::ThreadHeader.new(".c-routes.--channel-thread")
      end

      def notifications_button
        @notifications_button ||=
          PageObjects::Components::NotificationsTracking.new(".thread-notifications-tracking")
      end

      def notification_level=(level)
        notifications_button.toggle
        notifications_button.select_level_id(
          ::Chat::UserChatThreadMembership.notification_levels[level.to_sym],
        )
        has_notification_level?(level)
      end

      def has_notification_level?(level)
        notifications_button.has_selected_level_id?(
          ::Chat::UserChatThreadMembership.notification_levels[level.to_sym],
        )
      end

      def selection_management
        @selection_management ||=
          PageObjects::Components::Chat::SelectionManagement.new(".chat-channel")
      end

      def has_selected_messages?(*messages)
        self.messages.has_selected_messages?(*messages)
      end

      def close
        header.find(".c-navbar__close-thread-button").click
      end

      def has_back_link_to_thread_list?(channel)
        header.has_css?(".c-navbar__back-button[href='#{channel.relative_url + "/t"}']")
      end

      def has_back_link_to_channel?(channel)
        header.has_css?(".c-navbar__back-button[href='#{channel.relative_url}']")
      end

      def back
        header.find(".c-navbar__back-button").click
      end

      def has_no_unread_list_indicator?
        has_no_css?(".c-navbar__back-button .chat-thread-header-unread-indicator")
      end

      def has_unread_list_indicator?(count:)
        has_css?(
          ".c-navbar__back-button .chat-thread-header-unread-indicator  .chat-thread-header-unread-indicator__number",
          text: count.to_s,
        )
      end

      def has_no_loading_skeleton?
        has_no_css?(".chat-thread .chat-skeleton")
      end

      def type_in_composer(input)
        find(".chat-thread .chat-composer__input").click # makes helper more reliable by ensuring focus is not lost
        find(".chat-thread .chat-composer__input").send_keys(input)
      end

      def fill_composer(input)
        find(".chat-thread .chat-composer__input").click # makes helper more reliable by ensuring focus is not lost
        find(".chat-thread .chat-composer__input").fill_in(with: input)
      end

      def click_composer
        if has_no_css?(".dialog-overlay", wait: 0) # we can't click composer if a dialog is open, in case of error for exampel
          find(".chat-thread .chat-composer__input").click # ensures autocomplete is closed and not masking anything
        end
      end

      def send_message(text = nil)
        text ||= Faker::Lorem.characters(number: SiteSetting.chat_minimum_message_length)
        text = text.chomp if text.present? # having \n on the end of the string counts as an Enter keypress
        composer.fill_in(with: text)
        click_send_message
        expect(page).to have_no_css(".chat-message.-not-processed")
        click_composer
        text
      end

      def click_send_message
        find(".chat-thread .chat-composer.is-send-enabled .chat-composer-button.-send").click
      end

      def expand_deleted_message(message)
        message_by_id(message.id).find(".chat-message-expand").click
      end

      def expand_message_actions(message)
        hover_message(message)
        click_more_button
      end

      def click_more_button
        find(".more-buttons").click
      end

      def hover_message(message)
        message = message_by_id(message.id)
        # Scroll to top of message so that the actions are not hidden
        page.scroll_to(message, align: :top)
        message.hover
        message
      end

      def react_to_message(message, emoji_name = nil)
        message = hover_message(message)

        if emoji_name
          message.find(".react-btn").click
        else
          message.find(".chat-message-actions [data-emoji-name=\"#{emoji_name}\"]").click
        end
      end

      def message_by_id(id)
        find(message_by_id_selector(id))
      end

      def message_by_id_selector(id)
        ".chat-thread .chat-messages-container .chat-message-container[data-id=\"#{id}\"]"
      end

      def edit_message(message, text = nil)
        messages.edit(message)
        send_message(message.message + " " + text) if text
      end

      def has_bookmarked_message?(message)
        find(message_by_id_selector(message.id) + ".-bookmarked")
      end
    end
  end
end
