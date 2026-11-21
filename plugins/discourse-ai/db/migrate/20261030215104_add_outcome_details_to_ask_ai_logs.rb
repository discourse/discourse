# frozen_string_literal: true
class AddOutcomeDetailsToAskAiLogs < ActiveRecord::Migration[8.1]
  def change
    add_column :ask_ai_logs, :ai_agent_id, :bigint
    add_column :ask_ai_logs, :llm_id, :bigint
    add_column :ask_ai_logs, :no_answer_reason, :integer
    add_column :ask_ai_logs, :time_to_outcome_ms, :integer
    add_column :ask_ai_logs, :answer_requested_at, :datetime
    add_column :ask_ai_logs, :ask_tab_opened_after_ms, :integer, null: false, default: 0
    add_column :ask_ai_logs, :ask_answer_seen_after_ms, :integer
    add_column :ask_ai_logs, :ask_result_clicked_tab, :string, null: false, default: ""
    add_column :ask_ai_logs, :ask_result_clicked_after_ms, :integer, null: false, default: 0
  end
end
