# frozen_string_literal: true

class SecurityLogOutInviteRedemptionInvitedUsers < ActiveRecord::Migration[7.0]
  def up
    # 20220606061813 was added shortly before the vulnerability was introduced
    vulnerable_since =
      DB.query_single(
        "SELECT created_at FROM schema_migration_details WHERE version='20220606061813'",
      )[
        0
      ]

    DB.exec(<<~SQL, vulnerable_since: vulnerable_since)
      DELETE FROM user_auth_tokens
      WHERE user_id IN (
        SELECT DISTINCT user_id
        FROM invited_users
        JOIN users ON invited_users.user_id = users.id
        WHERE invited_users.redeemed_at > :vulnerable_since
      )
    SQL

    DB.exec(<<~SQL, vulnerable_since: vulnerable_since)
      DELETE FROM user_api_keys
      WHERE user_id IN (
        SELECT DISTINCT user_id
        FROM invited_users
        JOIN users ON invited_users.user_id = users.id
        WHERE invited_users.redeemed_at > :vulnerable_since
      )
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
