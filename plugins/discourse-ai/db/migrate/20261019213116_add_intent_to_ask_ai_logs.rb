# frozen_string_literal: true
class AddIntentToAskAiLogs < ActiveRecord::Migration[8.1]
  def change
    add_column :ask_ai_logs, :ask_intent_heuristic, :string, null: false, default: ""
    add_column :ask_ai_logs, :ask_intent_model, :string, null: false, default: ""
    add_column :ask_ai_logs, :ask_intent_probability, :float, null: false, default: 0
  end
end
