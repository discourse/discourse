# frozen_string_literal: true

class UpdatePostReplyIndexes < ActiveRecord::Migration[6.0]
  # Adding and removing indexes concurrently doesn't work within transaction.
  # It also needs existence checks for indexes in case the migration fails and needs to run again.
  disable_ddl_transaction!

  def up
    if !index_exists?(:post_replies, [:post_id, :reply_post_id])
      add_index :post_replies, [:post_id, :reply_post_id], unique: true, algorithm: :concurrently
    end

    if !index_exists?(:post_replies, [:reply_post_id])
      add_index :post_replies, [:reply_post_id], algorithm: :concurrently
    end

    if index_exists?(:post_replies, [:post_id, :reply_id])
      remove_index :post_replies, column: [:post_id, :reply_id], algorithm: :concurrently
    end

    if index_exists?(:post_replies, [:reply_id])
      remove_index :post_replies, column: [:reply_id], algorithm: :concurrently
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
