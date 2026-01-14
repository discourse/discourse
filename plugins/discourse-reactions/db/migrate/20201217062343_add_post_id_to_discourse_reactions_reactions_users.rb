# frozen_string_literal: true

class AddPostIdToDiscourseReactionsReactionsUsers < ActiveRecord::Migration[6.0]
  def change
    add_column :discourse_reactions_reaction_users, :post_id, :integer

    add_index :discourse_reactions_reaction_users,
              %i[user_id post_id],
              unique: true,
              name: "user_id_post_id"
  end
end
