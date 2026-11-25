# frozen_string_literal: true
class RemoveEnforceSecondFactorOnExternalAuth < ActiveRecord::Migration[8.1]
  def up
    execute(<<~SQL)
      DELETE FROM site_settings WHERE name = 'enforce_second_factor_on_external_auth'
    SQL

    execute(<<~SQL)
      DELETE FROM site_setting_groups WHERE name = 'enforce_second_factor_on_external_auth'
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
