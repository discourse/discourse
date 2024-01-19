# frozen_string_literal: true

class DeleteOldRateLimitSearchAnon < ActiveRecord::Migration[7.0]
  def change
    execute "DELETE FROM site_settings WHERE name in ('rate_limit_search_anon_user', 'rate_limit_search_anon_global')"
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
