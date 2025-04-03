# frozen_string_literal: true
#
class EnableWelcomeBannerNewSites < ActiveRecord::Migration[7.2]
  def up
    execute <<~SQL if Migration::Helpers.existing_site?
      INSERT INTO site_settings(name, data_type, value, created_at, updated_at)
      VALUES('enable_welcome_banner', 5, 'f', NOW(), NOW())
      ON CONFLICT (name) DO NOTHING
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
