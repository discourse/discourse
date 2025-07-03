# frozen_string_literal: true
class MigrateExperimentalSystemThemesSiteSettingToEnum < ActiveRecord::Migration[7.2]
  def up
    execute <<~SQL
      UPDATE
        "site_settings"
      SET
        "data_type" = 8,
        "value" = 'foundation|horizon'
      WHERE
        "name" = 'experimental_system_themes' AND
        "value" = 't' AND
        "data_type" = 5
    SQL

    execute <<~SQL
      UPDATE
        "site_settings"
      SET
        "data_type" = 8,
        "value" = ''
      WHERE
        "name" = 'experimental_system_themes' AND
        "value" = 'f' AND
        "data_type" = 5
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
