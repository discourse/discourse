# frozen_string_literal: true

module DiscourseReactions::PostActionExtension
  def self.prepended(base)
    base.has_one :reaction_user,
                 ->(post_action) { where(user_id: post_action.user_id) },
                 foreign_key: :post_id,
                 primary_key: :post_id,
                 class_name: "DiscourseReactions::ReactionUser"
    base.has_one :reaction, class_name: "DiscourseReactions::Reaction", through: :reaction_user
  end

  def self.filter_reaction_likes_sql
    <<~SQL
      post_actions.post_action_type_id = :like
      AND post_actions.deleted_at IS NULL
      AND post_actions.post_id NOT IN (
        #{post_action_with_reaction_user_sql}
      )
    SQL
  end

  def self.post_action_with_reaction_user_sql
    <<~SQL
      SELECT discourse_reactions_reaction_users.post_id
      FROM discourse_reactions_reaction_users
      INNER JOIN discourse_reactions_reactions ON discourse_reactions_reactions.id = discourse_reactions_reaction_users.reaction_id
      WHERE discourse_reactions_reaction_users.user_id = post_actions.user_id
        AND discourse_reactions_reaction_users.post_id = post_actions.post_id
      AND discourse_reactions_reactions.reaction_value IN (:valid_reactions)
    SQL
  end
end
