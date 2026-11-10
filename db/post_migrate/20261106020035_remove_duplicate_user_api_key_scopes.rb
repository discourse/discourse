# frozen_string_literal: true

class RemoveDuplicateUserApiKeyScopes < ActiveRecord::Migration[8.1]
  def up
    execute <<~SQL
      DELETE FROM user_api_key_scopes
      WHERE id IN (
        SELECT id
        FROM (
          SELECT id,
                 ROW_NUMBER() OVER (
                   PARTITION BY user_api_key_id, name, allowed_parameters
                   ORDER BY id
                 ) AS row_number
          FROM user_api_key_scopes
        ) numbered
        WHERE row_number > 1
      )
    SQL

    execute <<~SQL
      DELETE FROM user_api_key_client_scopes
      WHERE id IN (
        SELECT id
        FROM (
          SELECT id,
                 ROW_NUMBER() OVER (
                   PARTITION BY user_api_key_client_id, name
                   ORDER BY id
                 ) AS row_number
          FROM user_api_key_client_scopes
        ) numbered
        WHERE row_number > 1
      )
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
