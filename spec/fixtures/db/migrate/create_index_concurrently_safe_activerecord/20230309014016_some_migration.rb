# frozen_string_literal: true

class SomeMigration < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def up
    remove_index :notifications, %i[user_id id], if_exists: true
    add_index :notifications, %i[user_id id], algorithm: :concurrently
  end

  def down
    raise "not tested"
  end
end
