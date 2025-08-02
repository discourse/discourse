# frozen_string_literal: true

class MigrateInstagramUserInfo < ActiveRecord::Migration[5.2]
  def up
    execute <<~SQL
    INSERT INTO user_associated_accounts (
      provider_name,
      provider_uid,
      user_id,
      info,
      last_used,
      created_at,
      updated_at
    )
      SELECT
        'instagram',
        instagram_user_id,
        user_id,
        json_build_object('nickname', screen_name),
        updated_at,
        created_at,
        updated_at
      FROM instagram_user_infos
      ORDER BY updated_at DESC
    ON CONFLICT (provider_name, provider_uid)
    DO NOTHING
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
