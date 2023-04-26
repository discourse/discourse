# frozen_string_literal: true

class AddDiscourseConnectAllowedRedirectDomainsToSiteSettings < ActiveRecord::Migration[7.0]
  def change
    execute <<~SQL
      INSERT INTO site_settings(name, data_type, value, created_at, updated_at)
      SELECT 'discourse_connect_allowed_redirect_domains', 8, '*', created_at, NOW()
      FROM site_settings
      WHERE name = 'discourse_connect_allows_all_return_paths' AND value = 't'
    SQL

    execute <<~SQL
      DELETE FROM site_settings
      WHERE name = 'discourse_connect_allows_all_return_paths'
    SQL
  end
end
