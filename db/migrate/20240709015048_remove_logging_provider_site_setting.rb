# frozen_string_literal: true

class RemoveLoggingProviderSiteSetting < ActiveRecord::Migration[7.1]
  def up
    execute "DELETE FROM site_settings WHERE name = 'logging_provider'"
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
