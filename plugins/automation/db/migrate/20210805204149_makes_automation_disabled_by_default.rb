# frozen_string_literal: true

class MakesAutomationDisabledByDefault < ActiveRecord::Migration[6.1]
  def change
    change_column_default :discourse_automation_automations, :enabled, false
  end
end
