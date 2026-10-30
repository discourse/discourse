# frozen_string_literal: true

class AddOpenCloseAtIndexToPolls < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def up
    remove_index :polls, :close_at, algorithm: :concurrently, if_exists: true
    add_index :polls,
              :close_at,
              where: "status = 0 AND close_at IS NOT NULL",
              algorithm: :concurrently
  end

  def down
    remove_index :polls, :close_at, algorithm: :concurrently, if_exists: true
  end
end
