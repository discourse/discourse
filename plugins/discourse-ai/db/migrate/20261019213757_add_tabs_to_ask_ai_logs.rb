# frozen_string_literal: true
class AddTabsToAskAiLogs < ActiveRecord::Migration[8.1]
  def change
    add_column :ask_ai_logs, :ask_tab_opened, :string, null: false, default: ""
    add_column :ask_ai_logs, :ask_tab_opened_reason, :string, null: false, default: ""
    add_column :ask_ai_logs, :ask_tab_switched_to, :string, null: false, default: ""
    add_column :ask_ai_logs, :ask_tab_switched_after_ms, :integer, null: false, default: 0
  end
end
