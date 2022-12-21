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
        find(".chat-composer .send-btn").click
      end

      def message_by_id(id)
        find(".chat-message-container[data-id=\"#{id}\"]")
      end

      def has_no_loading_skeleton?
        has_no_css?(".chat-skeleton")
      end

      def expand_message_actions(message)
        hover_message(message)
        click_more_buttons(message)
      end

      def hover_message(message)
        message_by_id(message.id).hover
      end

      def bookmark_message(message)
        hover_message(message)
        find(".bookmark-btn").click
      end

      def click_more_buttons(message)
        find(".more-buttons").click
      end

      def flag_message(message)
        hover_message(message)
        click_more_buttons(message)
        find("[data-value='flag']").click
      end

      def select_message(message)
        hover_message(message)
        click_more_buttons(message)
        find("[data-value='selectMessage']").click
      end

      def edit_message(message, text = nil)
        hover_message(message)
        click_more_buttons(message)
        find("[data-value='edit']").click

        send_message(text) if text
      end

      def send_message(text = nil)
        find(".chat-composer-input").fill_in(with: text)
        click_send_message
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
