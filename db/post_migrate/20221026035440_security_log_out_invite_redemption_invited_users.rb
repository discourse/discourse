# frozen_string_literal: true

class SecurityLogOutInviteRedemptionInvitedUsers < ActiveRecord::Migration[6.1]
  def up
    # On the stable branch, 20200311135425 is the closest migration before the vulnerability was introduced
    vulnerable_since = DB.query_single("SELECT created_at FROM schema_migration_details WHERE version='20200311135425'")[0]

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
