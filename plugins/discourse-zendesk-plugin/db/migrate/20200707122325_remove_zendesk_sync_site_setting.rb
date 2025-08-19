# frozen_string_literal: true

class RemoveZendeskSyncSiteSetting < ActiveRecord::Migration[6.0]
  def up
    execute "DELETE FROM site_settings WHERE name = 'zendesk_sync_enabled'"
    execute "DELETE FROM site_settings WHERE name = 'zendesk_signature_regex'"
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
