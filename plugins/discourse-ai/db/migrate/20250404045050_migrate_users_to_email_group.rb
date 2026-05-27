# frozen_string_literal: true
class MigrateUsersToEmailGroup < ActiveRecord::Migration[7.2]
  def up
    execute <<~SQL
      UPDATE discourse_automation_fields
      SET component = 'email_group_user'
      WHERE
        component = 'users' AND
        name = 'receivers' AND
        automation_id IN (SELECT id FROM discourse_automation_automations WHERE script = 'llm_report')
    SQL
  end

  def down
    execute <<~SQL
      UPDATE discourse_automation_fields
      SET component = 'users'
      WHERE
        component = 'email_group_user' AND
        name = 'receivers' AND
        automation_id IN (SELECT id FROM discourse_automation_automations WHERE script = 'llm_report')
    SQL
  end
end
