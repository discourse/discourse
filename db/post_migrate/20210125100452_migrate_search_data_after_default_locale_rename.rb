# frozen_string_literal: true

class MigrateSearchDataAfterDefaultLocaleRename < ActiveRecord::Migration[6.0]
  def up
    move_search_data("category_search_data")
    move_search_data("post_search_data")
    move_search_data("tag_search_data")
    move_search_data("topic_search_data")
    move_search_data("user_search_data")
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end

  private

  def move_search_data(table_name)
    execute <<~SQL
      UPDATE #{table_name} x
      SET locale = 'en'
      WHERE locale = 'en_US'
    SQL
  rescue
    # Probably a unique key constraint violation. A background job might have inserted conflicting data during the UPDATE.
    # We can safely ignore this error. The ReindexSearch job will eventually fix the data.
  end
end
