# frozen_string_literal: true

class AddSessionIdIndexToSearchLogs < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def up
    remove_index :search_logs, :session_id, algorithm: :concurrently, if_exists: true
    add_index :search_logs, :session_id, where: "session_id IS NOT NULL", algorithm: :concurrently
  end

  def down
    remove_index :search_logs, :session_id, algorithm: :concurrently, if_exists: true
  end
end
