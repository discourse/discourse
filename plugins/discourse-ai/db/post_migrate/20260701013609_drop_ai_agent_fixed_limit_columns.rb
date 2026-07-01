# frozen_string_literal: true

class DropAiAgentFixedLimitColumns < ActiveRecord::Migration[8.0]
  DROPPED_COLUMNS = { ai_agents: %i[max_context_posts execution_mode] }

  def up
    execute "UPDATE ai_agents SET compression_threshold = 80 WHERE compression_threshold IS NULL"
    change_column_null :ai_agents, :compression_threshold, false
    DROPPED_COLUMNS.each { |table, columns| Migration::ColumnDropper.execute_drop(table, columns) }
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
