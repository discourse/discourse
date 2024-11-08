# frozen_string_literal: true

class DropTopicReplyCount < ActiveRecord::Migration[6.0]
  DROPPED_COLUMNS = { user_stats: %i[topic_reply_count] }.freeze

  def up
    DROPPED_COLUMNS.each { |table, columns| Migration::ColumnDropper.execute_drop(table, columns) }
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
