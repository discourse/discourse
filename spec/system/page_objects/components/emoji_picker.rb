# frozen_string_literal: true

module PageObjects
  module Components
    class EmojiPicker < PageObjects::Components::Base
      def emoji_button_selector(emoji_name)
        ".emoji-picker .emoji[title='#{emoji_name}']"
      end

      def select_emoji(emoji_name)
        find(emoji_button_selector(emoji_name)).click
      end

      def search_emoji(emoji_name)
        # `fill_in` types the last character as a separate input event; when the two
        # land a debounce apart, results for the partial term render and are then replaced
        locator(".emoji-picker .filter-input").fill(emoji_name)
      end

      def has_emoji?(emoji_name)
        page.has_css?(emoji_button_selector(emoji_name))
      end

      def has_no_emoji?(emoji_name)
        page.has_no_css?(emoji_button_selector(emoji_name))
      end
    end
  end
end
