# frozen_string_literal: true

class AddLastPostedAtToUsers < ActiveRecord::Migration[4.2]
  def change
    add_column :users, :last_posted_at, :datetime, null: true
    add_index :users, :last_posted_at

    execute "UPDATE users
             SET last_posted_at = (SELECT MAX(posts.created_at)
                                   FROM posts
                                   WHERE posts.user_id = users.id)"
  end
end
