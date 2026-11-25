# frozen_string_literal: true

module DiscourseReactions
  module PostReaction
    class Toggle
      include Service::Base

      params do
        attribute :post_id, :integer
        attribute :reaction, :string

        validates :post_id, presence: true
        validates :reaction, presence: true
      end

      model :post
      policy :can_see_post
      policy :reaction_is_valid
      model :reaction_manager, :build_reaction_manager

      try(Discourse::InvalidAccess) { step :toggle_reaction }

      step :publish_post_acted
      step :publish_reaction_change

      private

      def fetch_post(params:)
        Post.find_by(id: params.post_id)
      end

      def can_see_post(guardian:, post:)
        guardian.can_see?(post)
      end

      def reaction_is_valid(params:)
        DiscourseReactions::Reaction.valid?(params.reaction)
      end

      def build_reaction_manager(params:, guardian:, post:)
        DiscourseReactions::ReactionManager.new(
          reaction_value: params.reaction,
          user: guardian.user,
          post: post,
        )
      end

      def toggle_reaction(reaction_manager:)
        reaction_manager.toggle!
      rescue ActiveRecord::RecordNotUnique
        # Concurrent toggles are idempotent from the caller's perspective.
      end

      def publish_post_acted(post:)
        post.publish_change_to_clients!(:acted)
      end

      def publish_reaction_change(post:, reaction_manager:)
        post.publish_message!(
          "/topic/#{post.topic_id}/reactions",
          {
            post_id: post.id,
            reactions: [
              reaction_manager.reaction_value,
              reaction_manager.previous_reaction_value,
            ].compact.uniq,
          },
        )
      end
    end
  end
end
