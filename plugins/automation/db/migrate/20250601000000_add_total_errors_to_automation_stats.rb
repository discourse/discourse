# frozen_string_literal: true

class AddTotalErrorsToAutomationStats < ActiveRecord::Migration[7.2]
  def change
    add_column :discourse_automation_stats, :total_errors, :integer, default: 0, null: false
  end
end
