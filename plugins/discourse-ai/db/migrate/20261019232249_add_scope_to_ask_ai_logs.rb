# frozen_string_literal: true
class AddScopeToAskAiLogs < ActiveRecord::Migration[8.1]
  def change
    add_column :ask_ai_logs, :ask_scope, :string, null: false, default: ""
    add_column :ask_ai_logs, :ask_scope_model, :string, null: false, default: ""
    add_column :ask_ai_logs, :ask_scope_probability, :float, null: false, default: 0
  end
end
