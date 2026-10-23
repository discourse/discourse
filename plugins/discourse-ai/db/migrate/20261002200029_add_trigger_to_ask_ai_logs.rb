# frozen_string_literal: true
class AddTriggerToAskAiLogs < ActiveRecord::Migration[8.1]
  def change
    add_column :ask_ai_logs, :ask_trigger, :string, null: false, default: ""
    add_column :ask_ai_logs, :ask_trigger_reason, :string, null: false, default: ""
  end
end
