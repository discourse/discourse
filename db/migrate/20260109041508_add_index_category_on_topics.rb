# frozen_string_literal: true
class AddIndexCategoryOnTopics < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def up
    execute "CREATE INDEX CONCURRENTLY IF NOT EXISTS index_topics_on_category_id ON topics (category_id) WHERE deleted_at IS NULL AND (archetype <> 'private_message');"
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
