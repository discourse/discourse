# frozen_string_literal: true
class RenameOffice365ToMicrosoft < ActiveRecord::Migration[6.1]
  CHANGES = [
    %w[office365_enabled microsoft_auth_enabled],
    %w[office365_client_id microsoft_auth_client_id],
    %w[office365_secret microsoft_auth_client_secret],
  ]

  def up
    CHANGES.each { |old, new| DB.exec(<<~SQL, old_name: old, new_name: new) }
        INSERT INTO site_settings (name, data_type, value, created_at, updated_at)
        SELECT :new_name, data_type, value, created_at, updated_at
        FROM site_settings
        WHERE name = :old_name
      SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
