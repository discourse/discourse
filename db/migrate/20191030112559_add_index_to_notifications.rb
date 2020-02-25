# frozen_string_literal: true

class AddIndexToNotifications < ActiveRecord::Migration[6.0]
  disable_ddl_transaction!

  def up
    if !index_exists?(:notifications, [:topic_id, :post_number])
      add_index :notifications, [:topic_id, :post_number], algorithm: :concurrently
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
