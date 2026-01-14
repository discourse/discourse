# frozen_string_literal: true

class ResetErroneousLikeReactionsCount < ActiveRecord::Migration[6.1]
  def up
    like_reaction = DB.query_single(<<~SQL).first || "heart"
      SELECT value
      FROM site_settings
      WHERE name = 'discourse_reactions_reaction_for_like'
    SQL

    # the model does this gsub
    # https://github.com/discourse/discourse-reactions/blob/10505af498ae99b6acc704bff6eb072bbffc2ade/app/models/discourse_reactions/reaction.rb#L25
    like_reaction = like_reaction.gsub("-", "")

    # AR enum in the Reaction model
    emoji_reaction_type = 0

    inconsistent_reactions =
      DB.query(<<~SQL, like_reaction: like_reaction, emoji_reaction_type: emoji_reaction_type)
      SELECT id
      FROM discourse_reactions_reactions
      WHERE
        reaction_type = :emoji_reaction_type AND
        reaction_value = :like_reaction AND
        reaction_users_count IS NOT NULL
    SQL

    return if inconsistent_reactions.size == 0
    ids = inconsistent_reactions.map(&:id)

    DB.exec(<<~SQL, ids: ids)
      DELETE FROM discourse_reactions_reaction_users
      WHERE reaction_id IN (:ids)
    SQL

    DB.exec(<<~SQL, ids: ids)
      UPDATE discourse_reactions_reactions
      SET reaction_users_count = NULL
      WHERE id IN (:ids)
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
