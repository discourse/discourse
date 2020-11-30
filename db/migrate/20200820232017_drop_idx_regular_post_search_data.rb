# frozen_string_literal: true

class DropIdxRegularPostSearchData < ActiveRecord::Migration[6.0]
  disable_ddl_transaction!

  def up
    execute <<~SQL
    DROP INDEX CONCURRENTLY IF EXISTS idx_regular_post_search_data
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
