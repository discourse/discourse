# frozen_string_literal: true

class AddUniqueIndexToGroupRequests < ActiveRecord::Migration[5.2]
  def change
    execute "DELETE FROM group_requests WHERE id NOT IN (SELECT MIN(id) FROM group_requests GROUP BY group_id, user_id)"
    add_index :group_requests, [:group_id, :user_id], unique: true
  end
end
