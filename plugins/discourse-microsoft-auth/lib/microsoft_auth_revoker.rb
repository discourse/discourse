# frozen_string_literal: true

class MicrosoftAuthRevoker
  def self.revoke
    # Deactive users using microsoft as an authentication provider
    DB.exec <<~SQL
      UPDATE users SET active = false
      WHERE users.id IN (#{microsoft_user_associated_accounts_sql})
    SQL

    # Log out all users using microsoft as an authentication provider
    log_out_users

    # Revoke user API keys for users using microsoft as an authentication provider
    DB.exec <<~SQL
    UPDATE user_api_keys
    SET revoked_at = NOW()
    WHERE user_id IN (#{microsoft_user_associated_accounts_sql})
    SQL

    # Revoke API keys that are created by users using microsoft as an authentication provider
    DB.exec <<~SQL
    UPDATE api_keys
    SET revoked_at = NOW()
    WHERE created_by_id IN (#{microsoft_user_associated_accounts_sql})
    SQL

    # Remove microsoft as an authentication provider for all users
    DB.exec <<~SQL
    DELETE FROM user_associated_accounts
    WHERE provider_name = 'microsoft_office365'
    SQL
  end

  def self.log_out_users
    DB.exec <<~SQL
        DELETE FROM user_auth_tokens
        WHERE user_id IN (#{microsoft_user_associated_accounts_sql})
        SQL
  end

  def self.microsoft_user_associated_accounts_sql
    <<~SQL
    SELECT user_id
    FROM user_associated_accounts
    WHERE provider_name = 'microsoft_office365'
    SQL
  end
end
