# frozen_string_literal: true

module PageObjects
  module Pages
    class ChatChannel < PageObjects::Pages::Base
      def replying_to?(message)
        find(".chat-channel .chat-reply", text: message.message)
      end

      def type_in_composer(input)
        find(".chat-channel .chat-composer__input").click # makes helper more reliable by ensuring focus is not lost
        find(".chat-channel .chat-composer__input").send_keys(input)
      end

      def fill_composer(input)
        find(".chat-channel .chat-composer__input").click # makes helper more reliable by ensuring focus is not lost
        find(".chat-channel .chat-composer__input").fill_in(with: input)
      end

      def click_composer
        find(".chat-channel .chat-composer__input").click # ensures autocomplete is closed and not masking anything
      end

      def click_send_message
        find(".chat-composer.is-send-enabled .chat-composer__send-btn").click
      end

      def message_by_id_selector(id)
        ".chat-channel .chat-messages-container .chat-message-container[data-id=\"#{id}\"]"
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
        find(".chat-message-actions [data-id=\"#{message_action}\"]").click
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

      def copy_link(message)
        hover_message(message)
        click_more_button
        find("[data-value='copyLink']").click
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
        if page.has_css?("html.mobile-view", wait: 0)
          click_message_action_mobile(message, "reply")
        else
          hover_message(message)
          find(".reply-btn").click
        end
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
        check_message_presence(exists: true, text: text, id: id)
      end

      def has_no_message?(text: nil, id: nil)
        check_message_presence(exists: false, text: text, id: id)
      end

      def check_message_presence(exists: true, text: nil, id: nil)
        css_method = exists ? :has_css? : :has_no_css?
        if text
          find(".chat-channel").send(css_method, ".chat-message-text", text: text, wait: 5)
        elsif id
          find(".chat-channel").send(
            css_method,
            ".chat-message-container[data-id=\"#{id}\"]",
            wait: 10,
          )
        end
      end

      def has_thread_indicator?(message, text: nil)
        has_css?(message_thread_indicator_selector(message), text: text)
      end

      def has_no_thread_indicator?(message, text: nil)
        has_no_css?(message_thread_indicator_selector(message), text: text)
      end

      def message_thread_indicator(message)
        find(message_thread_indicator_selector(message))
      end

      private

      def message_thread_indicator_selector(message)
        "#{message_by_id_selector(message.id)} .chat-message-thread-indicator"
      end
    end
  end
end
