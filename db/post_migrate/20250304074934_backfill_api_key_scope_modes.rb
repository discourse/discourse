# frozen_string_literal: true

class BackfillApiKeyScopeModes < ActiveRecord::Migration[7.2]
  def up
    DB.exec(<<~SQL)
      UPDATE api_keys
      SET scope_mode = (
        CASE
          -- No associated `api_key_scopes` means global.
          WHEN NOT EXISTS (
            SELECT 1 FROM api_key_scopes aks WHERE aks.api_key_id = api_keys.id
          ) THEN 0

          -- Single associated `api_key_scope` with resource = 'global' and action = 'read' means read only.
          WHEN EXISTS (
            SELECT 1 FROM api_key_scopes aks 
            WHERE aks.api_key_id = api_keys.id
            AND aks.resource = 'global'
            AND aks.action = 'read'
            GROUP BY aks.api_key_id
            HAVING COUNT(*) = 1
          ) THEN 1
          
          -- Otherwise, associated scopes other than read only means granular.
          ELSE 2
        END
      );
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
