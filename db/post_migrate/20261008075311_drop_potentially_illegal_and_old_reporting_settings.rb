# frozen_string_literal: true

class DropPotentiallyIllegalAndOldReportingSettings < ActiveRecord::Migration[8.1]
  def up
    Migration::ColumnDropper.execute_drop(:reviewables, [:potentially_illegal])
    execute "DELETE FROM site_settings WHERE name IN ('allow_all_users_to_flag_illegal_content', 'email_address_to_report_illegal_content')"
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
