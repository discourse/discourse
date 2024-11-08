# frozen_string_literal: true

require "migration/column_dropper"

class RemoveHighestSeenPostNumberFromTopicUsers < ActiveRecord::Migration[6.1]
  DROPPED_COLUMNS = { topic_users: %i[highest_seen_post_number] }.freeze

  def up
    DROPPED_COLUMNS.each { |table, columns| Migration::ColumnDropper.execute_drop(table, columns) }
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
