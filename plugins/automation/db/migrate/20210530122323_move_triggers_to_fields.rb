# frozen_string_literal: true

class MoveTriggersToFields < ActiveRecord::Migration[6.1]
  def change
    add_column :discourse_automation_automations, :trigger, :string, null: true

    add_column :discourse_automation_fields, :target, :string, null: true

    DB.exec(<<~SQL)
        UPDATE discourse_automation_fields
        SET target = 'script'
      SQL
  end
end
