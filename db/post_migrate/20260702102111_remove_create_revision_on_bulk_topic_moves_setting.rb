# frozen_string_literal: true
class RemoveCreateRevisionOnBulkTopicMovesSetting < ActiveRecord::Migration[8.0]
  def up
    execute "DELETE FROM site_settings WHERE name = 'create_revision_on_bulk_topic_moves'"
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
