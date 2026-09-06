# frozen_string_literal: true

class AddSearchLogsCreatedAtExcludingCrawlersIndex < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  INDEX_NAME = "index_search_logs_on_created_at_excluding_crawlers"

  def up
    remove_index :search_logs, name: INDEX_NAME, algorithm: :concurrently, if_exists: true
    add_index :search_logs,
              :created_at,
              name: INDEX_NAME,
              where: "NOT crawler AND NOT likely_crawler",
              algorithm: :concurrently
  end

  def down
    remove_index :search_logs, name: INDEX_NAME, algorithm: :concurrently, if_exists: true
  end
end
