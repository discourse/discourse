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
        @header ||= PageObjects::Components::Chat::ThreadHeader.new(".chat-thread")
      end

      def notifications_button
        @notifications_button ||=
          PageObjects::Components::SelectKit.new(".thread-notifications-button")
      end

      def notification_level=(level)
        notifications_button.expand
        notifications_button.select_row_by_value(
          ::Chat::UserChatThreadMembership.notification_levels[level.to_sym],
        )
        notifications_button.has_selected_value?(
          ::Chat::UserChatThreadMembership.notification_levels[level.to_sym],
        )
      end

      def has_notification_level?(level)
        select_kit =
          PageObjects::Components::SelectKit.new(
            ".chat-thread-header__buttons.-persisted .thread-notifications-button",
          )
        select_kit.has_selected_value?(
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
        header.find(".chat-thread__close").click
      end

      def has_back_link_to_thread_list?(channel)
        header.has_css?(
          ".chat-thread__back-to-previous-route[href='#{channel.relative_url + "/t"}']",
        )
      end

      def has_back_link_to_channel?(channel)
        header.has_css?(".chat-thread__back-to-previous-route[href='#{channel.relative_url}']")
      end

      def back_to_previous_route
        header.find(".chat-thread__back-to-previous-route").click
      end

      def has_no_unread_list_indicator?
        has_no_css?(".chat-thread__back-to-previous-route .chat-thread-header-unread-indicator")
      end

      def has_unread_list_indicator?(count:)
        has_css?(
          ".chat-thread__back-to-previous-route .chat-thread-header-unread-indicator  .chat-thread-header-unread-indicator__number",
          text: count.to_s,
        )
      end

      def has_no_loading_skeleton?
        has_no_css?(".chat-thread__messages .chat-skeleton")
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
        find(".chat-thread .chat-composer__input").click # ensures autocomplete is closed and not masking anything
      end

      def send_message(text = nil)
        text ||= Faker::Lorem.characters(number: SiteSetting.chat_minimum_message_length)
        text = text.chomp if text.present? # having \n on the end of the string counts as an Enter keypress
        composer.fill_in(with: text)
        click_send_message
        click_composer
        text
      end

      def click_send_message
        find(".chat-thread .chat-composer.is-send-enabled .chat-composer-button.-send").click
      end

      def expand_deleted_message(message)
        message_by_id(message.id).find(".chat-message-expand").click
      end

      def copy_link(message)
        expand_message_actions(message)
        find("[data-value='copyLink']").click
      end

      def delete_message(message)
        expand_message_actions(message)
        find("[data-value='delete']").click
      end

      def restore_message(message)
        expand_deleted_message(message)
        expand_message_actions(message)
        find("[data-value='restore']").click
      end

      def expand_message_actions(message)
        hover_message(message)
        click_more_button
      end

      def click_more_button
        find(".more-buttons").click
      end

      def hover_message(message)
        message_by_id(message.id).hover
      end

      def message_by_id(id)
        find(message_by_id_selector(id))
      end

      def message_by_id_selector(id)
        ".chat-thread .chat-messages-container .chat-message-container[data-id=\"#{id}\"]"
      end

      def open_edit_message(message)
        hover_message(message)
        click_more_button
        find("[data-value='edit']").click
      end

      def edit_message(message, text = nil)
        open_edit_message(message)
        send_message(message.message + text) if text
      end
    end
  end
end
