# frozen_string_literal: true

class MigrateCustomFieldToPolicyUsers < ActiveRecord::Migration[5.2]
  def up
    execute(<<~SQL)
    INSERT INTO policy_users(post_policy_id, user_id, version, accepted_at, created_at, updated_at)
    SELECT post_policies.id, post_custom_fields.value::INTEGER, post_policies.version, post_custom_fields.created_at, post_custom_fields.created_at, post_custom_fields.updated_at
    FROM post_custom_fields
    INNER JOIN post_policies ON post_policies.post_id = post_custom_fields.post_id
    WHERE post_custom_fields.name = 'PolicyAcceptedBy'
    SQL

    execute(<<~SQL)
    DELETE FROM post_custom_fields WHERE name = 'PolicyAcceptedBy'
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
