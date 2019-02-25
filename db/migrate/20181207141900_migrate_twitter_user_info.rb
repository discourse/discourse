class MigrateTwitterUserInfo < ActiveRecord::Migration[5.2]
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
    ) SELECT
      'twitter',
      twitter_user_id,
      user_id,
      json_build_object('email', email, 'nickname', screen_name),
      updated_at,
      created_at,
      updated_at
    FROM twitter_user_infos
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
