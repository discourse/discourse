# frozen_string_literal: true

class CreateDiscourseReactionsReactionsTable < ActiveRecord::Migration[6.0]
  def change
    create_table :discourse_reactions_reactions do |t|
      t.integer :post_id
      t.integer :reaction_type
      t.string :reaction_value
      t.integer :reaction_users_count
      t.timestamps
    end
    add_index :discourse_reactions_reactions, :post_id
    add_index :discourse_reactions_reactions,
              %i[post_id reaction_type reaction_value],
              unique: true,
              name: "reaction_type_reaction_value"
  end
end
