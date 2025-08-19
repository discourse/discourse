# frozen_string_literal: true
class EnableHorizonForExistingSites < ActiveRecord::Migration[7.2]
  def change
    execute <<~SQL if Migration::Helpers.existing_site?
        INSERT INTO site_settings(name, data_type, value, created_at, updated_at)
        VALUES('experimental_system_themes', 8, 'horizon', NOW(), NOW())
        ON CONFLICT (name) DO NOTHING
      SQL
  end
end
