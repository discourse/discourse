# frozen_string_literal: true

class MigrateGithubUserInfos < ActiveRecord::Migration[6.0]
  def up
    # If the user_associated_accounts table is currently empty,
    # maintain the primary key from github_user_infos
    # This is useful for people that are using data explorer to access the data
    maintain_ids = DB.query_single("SELECT count(*) FROM user_associated_accounts")[0] == 0

    execute <<~SQL
      INSERT INTO user_associated_accounts (
        provider_name,
        provider_uid,
        user_id,
        info,
        last_used,
        created_at,
        updated_at
        #{", id" if maintain_ids}
      ) SELECT
        'github',
        github_user_id,
        user_id,
        json_build_object('nickname', screen_name),
        updated_at,
        created_at,
        updated_at
        #{", id" if maintain_ids}
      FROM github_user_infos
    SQL

    execute <<~SQL if maintain_ids
        SELECT setval(
          pg_get_serial_sequence('user_associated_accounts', 'id'),
          (select greatest(max(id), 1) from user_associated_accounts)
        );
      SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
