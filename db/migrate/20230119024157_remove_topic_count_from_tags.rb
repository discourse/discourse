# frozen_string_literal: true

require "migration/column_dropper"

class RemoveTopicCountFromTags < ActiveRecord::Migration[7.0]
  DROPPED_COLUMNS = { tags: %i[topic_count] }.freeze

  def up
    DROPPED_COLUMNS.each { |table, columns| Migration::ColumnDropper.execute_drop(table, columns) }
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
