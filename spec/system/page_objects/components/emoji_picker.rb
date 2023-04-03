# frozen_string_literal: true

module PageObjects
  module Components
    class EmojiPicker < PageObjects::Components::Base
      def select_emoji(emoji_name)
        find(".emoji-picker .emoji[title='#{emoji_name}']").click
      end

      def search_emoji(emoji_name)
        find(".emoji-picker .search input").fill_in(with: emoji_name)
      end

      def has_emoji?(emoji_name)
        page.has_css?(".emoji-picker .emoji[title='#{emoji_name}']")
      end
    end
  end
end
