# frozen_string_literal: true

class ReindexInvalidIndexes < ActiveRecord::Migration[7.0]
  disable_ddl_transaction!

  def up
    invalid_index_names = DB.query_single(<<~SQL)
    SELECT
      pg_class.relname
    FROM pg_class, pg_index, pg_namespace
    WHERE pg_index.indisvalid = false
    AND pg_index.indexrelid = pg_class.oid
    AND pg_namespace.nspname = 'public'
    AND relnamespace = pg_namespace.oid;
    SQL

    invalid_index_names.each { |index_name| execute "REINDEX INDEX CONCURRENTLY #{index_name}" }
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
