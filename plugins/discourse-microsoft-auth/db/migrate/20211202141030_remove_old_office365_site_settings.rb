# frozen_string_literal: true
class RemoveOldOffice365SiteSettings < ActiveRecord::Migration[6.1]
  def up
    execute "DELETE FROM site_settings WHERE name IN ('office365_enabled', 'office365_client_id', 'office365_secret')"
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
