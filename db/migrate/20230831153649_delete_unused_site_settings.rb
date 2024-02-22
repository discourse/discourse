# frozen_string_literal: true

class DeleteUnusedSiteSettings < ActiveRecord::Migration[7.0]
  def up
    execute <<~SQL
      DELETE
      FROM
        "site_settings"
      WHERE
        "name" IN (
          'rate_limit_new_user_create_topic',
          'enable_system_avatars',
          'check_for_new_features',
          'allow_user_api_keys'
        )
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
