# frozen_string_literal: true
class RemoveReportingImprovementsSetting < ActiveRecord::Migration[8.0]
  def up
    execute(<<~SQL)
      DELETE FROM site_settings WHERE name = 'reporting_improvements'
    SQL

    execute(<<~SQL)
      DELETE FROM site_setting_groups WHERE name = 'reporting_improvements'
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
