# frozen_string_literal: true

class DeleteUnverifiedPatreonUserInfo < ActiveRecord::Migration[6.1]
  def up
    execute <<~SQL
      DELETE FROM user_auth_tokens
      WHERE user_id IN (
        SELECT user_id
        FROM user_associated_accounts
        WHERE provider_name = 'patreon'
        AND COALESCE(JSON_EXTRACT_PATH(extra::json, 'raw_info', 'data', 'attributes', 'is_email_verified')::text, 'false') <> 'true'
      )
    SQL

    execute <<~SQL
      UPDATE user_api_keys
      SET revoked_at = NOW()
      WHERE user_id IN (
        SELECT user_id
        FROM user_associated_accounts
        WHERE provider_name = 'patreon'
        AND COALESCE(JSON_EXTRACT_PATH(extra::json, 'raw_info', 'data', 'attributes', 'is_email_verified')::text, 'false') <> 'true'
      )
    SQL

    execute <<~SQL
      UPDATE api_keys
      SET revoked_at = NOW()
      WHERE created_by_id IN (
        SELECT user_id
        FROM user_associated_accounts
        WHERE provider_name = 'patreon'
        AND COALESCE(JSON_EXTRACT_PATH(extra::json, 'raw_info', 'data', 'attributes', 'is_email_verified')::text, 'false') <> 'true'
      )
    SQL

    execute <<~SQL
      DELETE FROM user_associated_accounts
      WHERE provider_name = 'patreon'
      AND COALESCE(JSON_EXTRACT_PATH(extra::json, 'raw_info', 'data', 'attributes', 'is_email_verified')::text, 'false') <> 'true'
    SQL
  end

  def down
    # noop
  end
end
