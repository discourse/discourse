# frozen_string_literal: true

class CreateDiscourseReactionsReactionUsersTable < ActiveRecord::Migration[6.0]
  def change
    create_table :discourse_reactions_reaction_users do |t|
      t.integer :reaction_id
      t.integer :user_id
      t.timestamps
    end
    add_index :discourse_reactions_reaction_users, :reaction_id
    add_index :discourse_reactions_reaction_users,
              %i[reaction_id user_id],
              unique: true,
              name: "reaction_id_user_id"
  end
end
