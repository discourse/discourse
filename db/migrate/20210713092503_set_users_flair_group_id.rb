# frozen_string_literal: true

class SetUsersFlairGroupId < ActiveRecord::Migration[6.1]
  def change
    execute <<~SQL
      UPDATE users
      SET flair_group_id = primary_group_id
      WHERE flair_group_id IS NULL
    SQL
  end
end
