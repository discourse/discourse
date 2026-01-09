# frozen_string_literal: true

class DropPrefersEncryptFromPendingPms < ActiveRecord::Migration[8.0]
  DROPPED_COLUMNS = { discourse_automation_pending_pms: %i[prefers_encrypt] }

  def up
    DROPPED_COLUMNS.each { |table, columns| Migration::ColumnDropper.execute_drop(table, columns) }
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
