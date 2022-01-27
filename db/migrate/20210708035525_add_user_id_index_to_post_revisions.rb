# frozen_string_literal: true

class AddUserIdIndexToPostRevisions < ActiveRecord::Migration[6.1]
  def change
    add_index :post_revisions, :user_id
  end
end
