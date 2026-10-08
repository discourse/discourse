# frozen_string_literal: true

class DropPotentiallyIllegalAndOldReportingSettings < ActiveRecord::Migration[8.1]
  DROPPED_COLUMNS = { reviewables: %i[potentially_illegal] }

  def up
    DROPPED_COLUMNS.each { |table, columns| Migration::ColumnDropper.execute_drop(table, columns) }
    execute "DELETE FROM site_settings WHERE name IN ('allow_all_users_to_flag_illegal_content', 'email_address_to_report_illegal_content')"
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
