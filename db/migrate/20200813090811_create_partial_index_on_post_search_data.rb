# frozen_string_literal: true

class CreatePartialIndexOnPostSearchData < ActiveRecord::Migration[6.0]
  disable_ddl_transaction!

  def up
    execute <<~SQL
    CREATE INDEX CONCURRENTLY idx_regular_post_search_data ON post_search_data USING GIN(search_data) WHERE NOT private_message
    SQL
  end

  def down
    execute <<~SQL
    DROP INDEX IF EXISTS idx_regular_post_search_data;
    SQL
  end
end
