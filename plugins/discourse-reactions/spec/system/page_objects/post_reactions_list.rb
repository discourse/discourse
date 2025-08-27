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

      def context_component
        page.find(@context)
      end

      def post_id
        context_component["data-post-id"]
      end

      def reaction_list_emoji_selector(reaction)
        "#discourse-reactions-list-emoji-#{post_id}-#{reaction}"
      end

      def has_reaction?(reaction)
        component.has_css?(reaction_list_emoji_selector(reaction))
      end

      def hover_over_reaction(reaction)
        component.find(reaction_list_emoji_selector(reaction)).hover
        page.has_css?(".discourse-reactions-list-emoji .user-list", visible: true)
      end

      def click_reaction(reaction)
        component.find(reaction_list_emoji_selector(reaction)).click
      end

      def has_users_for_reaction?(reaction, usernames)
        find("#{reaction_list_emoji_selector(reaction)} .user-list .container").has_text?(
          usernames.join("\n"),
        )
      end
    end
  end
end
