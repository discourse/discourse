# frozen_string_literal: true

module PageObjects
  module Pages
    class ChatChannel < PageObjects::Pages::Base
      def type_in_composer(input)
        find(".chat-composer-input").send_keys(input)
      end

      def fill_composer(input)
        find(".chat-composer-input").fill_in(with: input)
      end

      def click_send_message
        find(".chat-composer .send-btn:enabled").click
      end

      def message_by_id(id)
        find(".chat-message-container[data-id=\"#{id}\"]")
      end

      def has_no_loading_skeleton?
        has_no_css?(".chat-skeleton")
      end

      def has_selection_management?
        has_css?(".chat-selection-management")
      end

      def expand_message_actions(message)
        hover_message(message)
        click_more_button
      end

      def expand_message_actions_mobile(message, delay: 2)
        message_by_id(message.id).click(delay: delay)
      end

      def click_message_action_mobile(message, message_action)
        expand_message_actions_mobile(message, delay: 0.5)
        wait_for_animation(find(".chat-message-actions"), timeout: 5)
        find(".chat-message-action-item[data-id=\"#{message_action}\"] button").click
      end

      def hover_message(message)
        message_by_id(message.id).hover
      end

      def bookmark_message(message)
        hover_message(message)
        find(".bookmark-btn").click
      end

      def click_more_button
        find(".more-buttons").click
      end

      def flag_message(message)
        hover_message(message)
        click_more_button
        find("[data-value='flag']").click
      end

      def flag_message(message)
        hover_message(message)
        click_more_button
        find("[data-value='flag']").click
      end

      def open_message_thread(message)
        hover_message(message)
        find(".chat-message-thread-btn").click
      end

      def select_message(message)
        hover_message(message)
        click_more_button
        find("[data-value='selectMessage']").click
      end

      def delete_message(message)
        hover_message(message)
        click_more_button
        find("[data-value='deleteMessage']").click
      end

      def open_edit_message(message)
        hover_message(message)
        click_more_button
        find("[data-value='edit']").click
      end

      def edit_message(message, text = nil)
        open_edit_message(message)
        send_message(text) if text
      end

      def send_message(text = nil)
        text = text.chomp if text.present? # having \n on the end of the string counts as an Enter keypress
        find(".chat-composer-input").click # makes helper more reliable by ensuring focus is not lost
        find(".chat-composer-input").fill_in(with: text)
        click_send_message
        find(".chat-composer-input").click # ensures autocomplete is closed and not masking anything
      end

      def reply_to(message)
        hover_message(message)
        find(".reply-btn").click
      end

      def has_bookmarked_message?(message)
        within(message_by_id(message.id)) { find(".chat-message-bookmarked") }
      end

      def find_reaction(message, reaction)
        within(message_reactions_list(message)) do
          return find("[data-emoji-name=\"#{reaction.emoji}\"]")
        end
      end

      def has_reaction?(message, reaction, text = nil)
        within(message_reactions_list(message)) do
          has_css?("[data-emoji-name=\"#{reaction.emoji}\"]", text: text)
        end
      end

      def message_reactions_list(message)
        within(message_by_id(message.id)) { find(".chat-message-reaction-list") }
      end

      def has_reactions?(message)
        within(message_by_id(message.id)) { has_css?(".chat-message-reaction-list") }
      end

      def has_no_reactions?(message)
        within(message_by_id(message.id)) { has_no_css?(".chat-message-reaction-list") }
      end

      def click_reaction(message, reaction)
        find_reaction(message, reaction).click
      end

      def open_action_menu
        find(".chat-composer-dropdown__trigger-btn").click
      end

      def click_action_button(action_button_class)
        find(".chat-composer-dropdown__action-btn.#{action_button_class}").click
      end

      def has_message?(text: nil, id: nil)
        if text
          has_css?(".chat-message-text", text: text)
        elsif id
          has_css?(".chat-message-container[data-id=\"#{id}\"]", wait: 10)
        end
      end
    end
  end
end
