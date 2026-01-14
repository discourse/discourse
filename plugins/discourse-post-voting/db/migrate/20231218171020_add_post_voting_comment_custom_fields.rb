# frozen_string_literal: true

class AddPostVotingCommentCustomFields < ActiveRecord::Migration[7.0]
  def change
    create_table :post_voting_comment_custom_fields do |t|
      t.integer :post_voting_comment_id, null: false
      t.string :name, limit: 256, null: false
      t.text :value
      t.timestamps null: false
    end

    add_index :post_voting_comment_custom_fields,
              %i[post_voting_comment_id name],
              name: :idx_post_voting_comment_custom_fields
  end
end
