# frozen_string_literal: true

module PageObjects
  module Components
    class PostReactionsButton < PageObjects::Components::Base
      attr_reader :context

      def initialize(context)
        @context = context
      end

      def post_reactions_actions_selector(post_id, position:)
        "#discourse-reactions-actions-#{post_id}-#{position}"
      end

      def hover_like_button(post_id)
        context_component.find(post_reactions_actions_selector(post_id, position: "right")).hover
      end

      def has_expanded_reactions_picker?(post_id)
        context_component.find(post_reactions_actions_selector(post_id, position: "right")).find(
          ".discourse-reactions-picker.is-expanded",
        )
      end

      def has_no_emoji?(emoji)
        has_no_css?(".pickable-reaction.#{emoji}")
      end

      def has_emoji?(emoji)
        has_css?(".pickable-reaction.#{emoji}")
      end

      def pick_reaction(emoji)
        find(".pickable-reaction.#{emoji}").click
      end

      def pick_any_reaction(emoji)
        open_emoji_picker
        filter_emoji_picker(emoji)
        find(".emoji-picker__section.filtered [data-emoji=\"#{emoji}\"]").click
      end

      def open_emoji_picker
        find(".emoji-picker-trigger").click
      end

      def filter_emoji_picker(emoji)
        find(".emoji-picker__filter .filter-input").fill_in(with: emoji)
      end

      def has_no_emoji_picker_emoji?(emoji)
        has_no_css?(".emoji-picker__section.filtered [data-emoji=\"#{emoji}\"]")
      end
    end
  end
end
