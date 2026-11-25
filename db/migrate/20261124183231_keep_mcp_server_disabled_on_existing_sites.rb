# frozen_string_literal: true

class KeepMcpServerDisabledOnExistingSites < ActiveRecord::Migration[8.1]
  def up
    return if !Migration::Helpers.existing_site?

    execute <<~SQL
      INSERT INTO site_settings (name, data_type, value, created_at, updated_at)
      VALUES ('mcp_server_enabled', 5, 'f', NOW(), NOW())
      ON CONFLICT DO NOTHING
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
