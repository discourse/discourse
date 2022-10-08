# frozen_string_literal: true

class ResetFlairGroupIdIfNotGroupMember < ActiveRecord::Migration[7.0]
  def change
    execute <<~SQL
      UPDATE users
      SET flair_group_id = NULL
      WHERE flair_group_id IS NOT NULL AND NOT EXISTS (
        SELECT 1
        FROM group_users
        WHERE group_users.user_id = users.id
          AND group_users.group_id = users.flair_group_id
      )
    SQL
  end
end
