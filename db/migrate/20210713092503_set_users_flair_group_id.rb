# frozen_string_literal: true

class SetUsersFlairGroupId < ActiveRecord::Migration[6.1]
  def change
    execute <<~SQL
      UPDATE users
      SET flair_group_id = primary_group_id
      FROM groups
      WHERE users.primary_group_id = groups.id AND
            users.flair_group_id IS NULL AND
            (groups.flair_icon IS NOT NULL OR groups.flair_upload_id IS NOT NULL)
    SQL
  end
end
