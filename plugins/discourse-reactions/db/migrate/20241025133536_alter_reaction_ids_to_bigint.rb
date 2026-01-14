# frozen_string_literal: true

class AlterReactionIdsToBigint < ActiveRecord::Migration[7.1]
  def up
    change_column :discourse_reactions_reaction_users, :reaction_id, :bigint
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
