# frozen_string_literal: true

class RemoveEnforceSecondFactorOnExternalAuth < ActiveRecord::Migration[8.1]
  def up
    execute "DELETE FROM site_settings WHERE name = 'enforce_second_factor_on_external_auth'"
    execute "DELETE FROM site_setting_groups WHERE name = 'enforce_second_factor_on_external_auth'"
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
