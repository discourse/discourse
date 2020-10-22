# frozen_string_literal: true

class DeleteTrackingStateForStagedUsers < ActiveRecord::Migration[6.0]
  def up
    execute <<~SQL
      DELETE FROM category_users
      WHERE user_id IN (SELECT id FROM users WHERE staged = true)
    SQL

    execute <<~SQL
      DELETE FROM tag_users
      WHERE user_id IN (SELECT id FROM users WHERE staged = true)
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
