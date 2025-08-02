# frozen_string_literal: true

class AlterAutomationIdsToBigint < ActiveRecord::Migration[7.1]
  def up
    change_column :discourse_automation_fields, :automation_id, :bigint
    change_column :discourse_automation_pending_automations, :automation_id, :bigint
    change_column :discourse_automation_pending_pms, :automation_id, :bigint
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
