# frozen_string_literal: true

class AddIndexToPostActionsOnPostActionTypeId < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def up
    execute <<~SQL
    DROP INDEX IF EXISTS index_post_actions_on_post_action_type_id;
    SQL

    execute <<~SQL
    CREATE INDEX CONCURRENTLY index_post_actions_on_post_action_type_id ON post_actions (post_action_type_id);
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
