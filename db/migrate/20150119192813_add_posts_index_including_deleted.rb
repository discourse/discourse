# frozen_string_literal: true

class AddPostsIndexIncludingDeleted < ActiveRecord::Migration[4.2]
  def change
    add_index :posts, [:user_id, :created_at]
  end
end
