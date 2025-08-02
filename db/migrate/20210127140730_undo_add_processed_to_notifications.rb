# frozen_string_literal: true
class UndoAddProcessedToNotifications < ActiveRecord::Migration[6.0]
  def up
    execute "ALTER TABLE notifications DROP COLUMN IF EXISTS processed"
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
