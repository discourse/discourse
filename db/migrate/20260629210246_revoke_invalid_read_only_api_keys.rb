# frozen_string_literal: true

class RevokeInvalidReadOnlyApiKeys < ActiveRecord::Migration[8.0]
  def up
    execute <<~SQL
      UPDATE api_keys
      SET revoked_at = CURRENT_TIMESTAMP,
          updated_at = CURRENT_TIMESTAMP
      WHERE scope_mode = 1
        AND revoked_at IS NULL
        AND NOT (
          (
            SELECT COUNT(*)
            FROM api_key_scopes
            WHERE api_key_scopes.api_key_id = api_keys.id
          ) = 1
          AND EXISTS (
            SELECT 1
            FROM api_key_scopes
            WHERE api_key_scopes.api_key_id = api_keys.id
              AND api_key_scopes.resource = 'global'
              AND api_key_scopes.action = 'read'
          )
        )
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
