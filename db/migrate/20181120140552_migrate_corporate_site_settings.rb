# frozen_string_literal: true

class MigrateCorporateSiteSettings < ActiveRecord::Migration[5.2]
  def up
    execute <<~SQL
      UPDATE site_settings
      SET name      = 'company_name'
      WHERE name = 'company_full_name';
    SQL

    execute <<~SQL
      DELETE
      FROM site_settings
      WHERE name IN ('company_short_name', 'company_domain');
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
