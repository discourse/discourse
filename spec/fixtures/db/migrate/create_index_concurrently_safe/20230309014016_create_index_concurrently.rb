# frozen_string_literal: true

class CreateIndexConcurrently < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def up
    execute <<~SQL
    DROP INDEX IF EXISTS some_notifications_index;
    SQL

    execute <<~SQL
    CREATE INDEX CONCURRENTLY some_notifications_index ON notifications(user_id);
    SQL
  end

  def down
    raise "not tested"
  end
end
