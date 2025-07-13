# frozen_string_literal: true

class RenameThumbsupReactions < ActiveRecord::Migration[6.1]
  def up
    current_reactions =
      DB.query_single(
        "SELECT value FROM site_settings WHERE name = 'discourse_reactions_enabled_reactions'",
      )[
        0
      ]

    alias_name = "thumbsup"
    original_name = "+1"

    if current_reactions
      updated_reactions = current_reactions.gsub(alias_name, original_name)

      DB.exec(<<~SQL, updated_reactions: updated_reactions)
        UPDATE site_settings
        SET value = :updated_reactions
        WHERE name = 'discourse_reactions_enabled_reactions'
      SQL
    end

    has_both_reactions = DB.query_single(<<~SQL, alias: alias_name, new_value: original_name)
      SELECT post_id
      FROM discourse_reactions_reactions
      WHERE reaction_value IN (:alias, :new_value)
      GROUP BY post_id
      HAVING COUNT(post_id) > 1
    SQL

    if has_both_reactions.present?
      reaction_ids = DB.exec(<<~SQL, conflicts: has_both_reactions, alias: alias_name)
        DELETE FROM discourse_reactions_reactions
        WHERE post_id IN (:conflicts) AND reaction_value = :alias
        RETURNING id
      SQL

      DB.exec(<<~SQL, deleted_reactions: reaction_ids)
        DELETE FROM discourse_reactions_reaction_users
        WHERE reaction_id IN (:deleted_reactions)
      SQL
    end

    DB.exec(<<~SQL, alias: alias_name, new_value: original_name, conflicts: has_both_reactions)
      UPDATE discourse_reactions_reactions
      SET reaction_value = :new_value
      WHERE reaction_value = :alias AND post_id NOT IN (:conflicts)
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
