# frozen_string_literal: true

module PageObjects
  module Components
    class PostReactionsList < PageObjects::Components::Base
      attr_reader :context

      SELECTOR = ".discourse-reactions-list"

      def initialize(context)
        @context = context
      end

      def component
        context_component.find(SELECTOR)
      end

      def post_id
        context_component["data-post-id"]
      end

      def reaction_list_emoji_selector(reaction)
        %([id="discourse-reactions-list-emoji-#{post_id}-#{reaction}"])
      end

      def has_reaction?(reaction)
        component.has_css?(reaction_list_emoji_selector(reaction))
      end

      def click_reaction(reaction)
        component.find(reaction_list_emoji_selector(reaction)).click
      end

      def click_counter
        context_component.find(".discourse-reactions-counter").click
      end
    end
  end
end
