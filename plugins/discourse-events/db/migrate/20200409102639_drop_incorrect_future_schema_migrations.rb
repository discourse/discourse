# frozen_string_literal: true

class DropIncorrectFutureSchemaMigrations < ActiveRecord::Migration[5.2]
  def up
    execute <<-SQL
      DELETE FROM schema_migrations WHERE version = '20201303000001';
      DELETE FROM schema_migration_details WHERE version = '20201303000001';
      DELETE FROM schema_migrations WHERE version = '20201303000002';
      DELETE FROM schema_migration_details WHERE version = '20201303000002';
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
