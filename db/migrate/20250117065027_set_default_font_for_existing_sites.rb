# frozen_string_literal: true

class SetDefaultFontForExistingSites < ActiveRecord::Migration[7.2]
  def up
    base_font_changed_from_default =
      DB.query_single("SELECT 1 FROM site_settings WHERE name = 'base_font'").first == 1
    heading_font_changed_from_default =
      DB.query_single("SELECT 1 FROM site_settings WHERE name = 'heading_font'").first == 1

    if !base_font_changed_from_default
      # Type 8 is 'list', arial is the current default font.
      execute <<~SQL if Migration::Helpers.existing_site?
        INSERT INTO site_settings(name, data_type, value, created_at, updated_at)
        VALUES('base_font', 8, 'arial', NOW(), NOW())
        ON CONFLICT (name) DO NOTHING
      SQL
    end

    if !heading_font_changed_from_default
      # Type 8 is 'list', arial is the current default font.
      execute <<~SQL if Migration::Helpers.existing_site?
        INSERT INTO site_settings(name, data_type, value, created_at, updated_at)
        VALUES('heading_font', 8, 'arial', NOW(), NOW())
        ON CONFLICT (name) DO NOTHING
      SQL
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
