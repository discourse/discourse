# frozen_string_literal: true

class RenameRateLimitSearchAnon < ActiveRecord::Migration[7.0]
  RENAME_SETTINGS = [
    %w[rate_limit_search_anon_user rate_limit_search_anon_user_per_minute],
    %w[rate_limit_search_anon_global rate_limit_search_anon_global_per_minute],
  ].freeze

  def up
    # Copying the rows so that things keep working during deploy
    # They will be dropped in post_migrate/..delete_old_rate_limit_search_anon
    #
    RENAME_SETTINGS.each { |old_name, new_name| execute <<~SQL }
        INSERT INTO site_settings (name, data_type, value, created_at, updated_at)
        SELECT '#{new_name}', data_type, value, created_at, updated_at
        FROM site_settings
        WHERE name = '#{old_name}'
      SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
