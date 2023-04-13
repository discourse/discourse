# frozen_string_literal: true

module PageObjects
  module Pages
    class ChatChannel < PageObjects::Pages::Base
      def type_in_composer(input)
        find(".chat-composer-input--channel").click # makes helper more reliable by ensuring focus is not lost
        find(".chat-composer-input--channel").send_keys(input)
      end

      def fill_composer(input)
        find(".chat-composer-input--channel").click # makes helper more reliable by ensuring focus is not lost
        find(".chat-composer-input--channel").fill_in(with: input)
      end

      def click_composer
        find(".chat-composer-input--channel").click # ensures autocomplete is closed and not masking anything
      end

      def click_send_message
        find(".chat-composer .send-btn:enabled").click
      end

      def message_by_id_selector(id)
        ".chat-live-pane .chat-messages-container .chat-message-container[data-id=\"#{id}\"]"
      end

      def message_by_id(id)
        find(message_by_id_selector(id))
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

      def select_message(message)
        hover_message(message)
        click_more_button
        find("[data-value='select']").click
      end

      def delete_message(message)
        hover_message(message)
        click_more_button
        find("[data-value='delete']").click
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
        fill_composer(text)
        click_send_message
        click_composer
      end

      def reply_to(message)
        hover_message(message)
        find(".reply-btn").click
      end

      def has_bookmarked_message?(message)
        within(message_by_id(message.id)) { find(".chat-message-bookmarked") }
      end

      def find_reaction(message, emoji)
        within(message_reactions_list(message)) { return find("[data-emoji-name=\"#{emoji}\"]") }
      end

      def has_reaction?(message, emoji, text = nil)
        within(message_reactions_list(message)) do
          has_css?("[data-emoji-name=\"#{emoji}\"]", text: text)
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

      def click_reaction(message, emoji)
        find_reaction(message, emoji).click
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

      def has_thread_indicator?(message)
        has_css?("#{message_by_id_selector(message.id)} .chat-message-thread-indicator")
      end

      def message_thread_indicator(message)
        find("#{message_by_id_selector(message.id)} .chat-message-thread-indicator")
      end
    end
  end
end
