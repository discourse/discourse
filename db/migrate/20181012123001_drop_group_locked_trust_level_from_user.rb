# frozen_string_literal: true

require "migration/column_dropper"

class DropGroupLockedTrustLevelFromUser < ActiveRecord::Migration[5.2]
  DROPPED_COLUMNS = { posts: %i[group_locked_trust_level] }.freeze

  def up
    DROPPED_COLUMNS.each { |table, columns| Migration::ColumnDropper.execute_drop(table, columns) }
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
