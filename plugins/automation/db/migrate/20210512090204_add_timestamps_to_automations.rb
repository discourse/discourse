# frozen_string_literal: true

class AddTimestampsToAutomations < ActiveRecord::Migration[6.1]
  def change
    add_column :discourse_automation_automations, :last_updated_by_id, :integer, null: true

    DB.exec(<<~SQL, user_id: Discourse::SYSTEM_USER_ID)
        UPDATE discourse_automation_automations
        SET last_updated_by_id = :user_id
      SQL

    execute <<~SQL
      ALTER TABLE discourse_automation_automations ALTER COLUMN last_updated_by_id SET NOT NULL;
    SQL
  end
end
