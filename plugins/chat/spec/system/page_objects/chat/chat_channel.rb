# frozen_string_literal: true

module PageObjects
  module Pages
    class ChatChannel < PageObjects::Pages::Base
      def composer
        @composer ||= PageObjects::Components::Chat::Composer.new(".chat-channel")
      end

      def messages
        @messages ||= PageObjects::Components::Chat::Messages.new(".chat-channel")
      end

      def selection_management
        @selection_management ||=
          PageObjects::Components::Chat::SelectionManagement.new(".chat-channel")
      end

      def has_selected_messages?(*messages)
        self.messages.has_selected_messages?(*messages)
      end

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
        if has_no_css?(".dialog-overlay", wait: 0) # we can't click composer if a dialog is open, in case of error for exampel
          find(".chat-channel .chat-composer__input").click # ensures autocomplete is closed and not masking anything
        end
      end

      def click_send_message
        find(".chat-composer.is-send-enabled .chat-composer-button.-send").click
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

      def expand_deleted_message(message)
        message_by_id(message.id).find(".chat-message-expand").click
      end

      def expand_message_actions(message)
        hover_message(message)
        click_more_button
      end

      def expand_message_actions_mobile(message, delay: 2)
        find(message_by_id_selector(message.id)).find(".chat-message-content").click(delay: delay)
      end

      def click_message_action_mobile(message, message_action)
        expand_message_actions_mobile(message, delay: 0.4)
        find(".chat-message-actions [data-id=\"#{message_action}\"]").click
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
          message.find(".chat-message-actions [data-emoji-name=\"#{emoji_name}\"]").click
        else
          message.find(".react-btn").click
        end
      end

      def bookmark_message(message)
        if page.has_css?("html.mobile-view", wait: 0)
          click_message_action_mobile(message, "bookmark")
          expect(page).to have_css(".d-modal:not(.is-animating)")
        else
          hover_message(message)
          find(".bookmark-btn").click
        end
      end

      def click_more_button
        find(".more-buttons").click
      end

      def edit_message(message, text = nil)
        messages.edit(message)
        send_message(message.message + " " + text) if text
      end

      def send_message(text = nil)
        text ||= fake_chat_message
        text = text.chomp if text.present? # having \n on the end of the string counts as an Enter keypress
        composer.fill_in(with: text)
        click_send_message
        expect(page).to have_no_css(".chat-message.-not-processed")
        text
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
        find(message_by_id_selector(message.id) + ".-bookmarked")
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

      def has_thread_indicator?(message)
        message_thread_indicator(message).exists?
      end

      def has_no_thread_indicator?(message)
        message_thread_indicator(message).does_not_exist?
      end

      def message_thread_indicator(message)
        PageObjects::Components::Chat::ThreadIndicator.new(message_by_id_selector(message.id))
      end

      def open_thread_list
        find(thread_list_button_selector).click
        PageObjects::Components::Chat::ThreadList.new.has_loaded?
      end

      def has_unread_thread_indicator?(count:)
        has_css?("#{thread_list_button_selector}.has-unreads") &&
          has_css?(
            ".chat-thread-header-unread-indicator .chat-thread-header-unread-indicator__number",
            text: count.to_s,
          )
      end

      def has_no_unread_thread_indicator?
        has_no_css?("#{thread_list_button_selector}.has-unreads")
      end

      def thread_list_button_selector
        ".c-navbar__threads-list-button"
      end

      private

      def message_thread_indicator_selector(message)
        "#{message_by_id_selector(message.id)} .chat-message-thread-indicator"
      end
    end
  end
end
