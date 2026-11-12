# frozen_string_literal: true

class MarkAiAgentFixedLimitColumnsReadonly < ActiveRecord::Migration[8.0]
  COLUMNS = %i[max_context_posts execution_mode]

  def up
    execute "UPDATE ai_agents SET compression_threshold = 80 WHERE compression_threshold IS NULL"
    change_column_default :ai_agents, :compression_threshold, 80
    change_column_null :ai_agents, :execution_mode, true
    change_column_default :ai_agents, :execution_mode, nil
    COLUMNS.each { |column| Migration::ColumnDropper.mark_readonly(:ai_agents, column) }
  end

  def down
    change_column_default :ai_agents, :compression_threshold, nil
    COLUMNS.each { |column| Migration::ColumnDropper.drop_readonly(:ai_agents, column) }
    execute "UPDATE ai_agents SET execution_mode = 'default' WHERE execution_mode IS NULL"
    change_column_default :ai_agents, :execution_mode, "default"
    change_column_null :ai_agents, :execution_mode, false
  end
end
