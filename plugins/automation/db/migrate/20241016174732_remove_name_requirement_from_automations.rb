# frozen_string_literal: true

class RemoveNameRequirementFromAutomations < ActiveRecord::Migration[7.1]
  def change
    change_column_null :discourse_automation_automations, :name, true
  end
end
