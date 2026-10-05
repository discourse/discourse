# frozen_string_literal: true

# For a most user / received reactions cards
module DiscourseRewind
  module Action
    class Reactions < BaseReport
      MAX_REACTIONS = 5
      FAKE_REACTIONS = [
        { emoji: "grinning", count: 82 },
        { emoji: "heart", count: 45 },
        { emoji: "dog", count: 34 },
        { emoji: "cat", count: 32 },
        { emoji: "open_mouth", count: 2 },
      ].freeze

      FakeData = {
        data: {
          post_received_reactions: FAKE_REACTIONS,
          post_used_reactions: FAKE_REACTIONS,
          post_used_reactions_total: FAKE_REACTIONS.sum { |reaction| reaction[:count] },
        },
        identifier: "reactions",
      }

      def call
        return FakeData if should_use_fake_data?

        used = count_by_emoji(DiscourseReactions::Reaction.by_user(user))
        received =
          count_by_emoji(
            DiscourseReactions::Reaction.joins(:reaction_users, :post).where(
              posts: {
                user_id: user.id,
              },
            ),
          )
        return if used.empty? && received.empty?

        {
          data: {
            post_used_reactions: used.first(MAX_REACTIONS),
            post_used_reactions_total: used.sum { |reaction| reaction[:count] },
            post_received_reactions: received.first(MAX_REACTIONS),
          },
          identifier: "reactions",
        }
      end

      def self.enabled?
        plugin_enabled?("discourse-reactions")
      end

      private

      def count_by_emoji(reactions)
        reactions
          .where(discourse_reactions_reaction_users: { created_at: date })
          .group(:reaction_value)
          .order("COUNT(*) DESC, reaction_value")
          .count
          .map { |emoji, count| { emoji:, count: } }
      end
    end
  end
end
