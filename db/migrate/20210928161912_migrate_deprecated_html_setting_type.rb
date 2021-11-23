# frozen_string_literal: true

class MigrateDeprecatedHtmlSettingType < ActiveRecord::Migration[6.1]
  def up
    execute <<~SQL
      UPDATE site_settings
      SET data_type = 1
      WHERE data_type = 25
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
