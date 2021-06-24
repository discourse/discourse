# frozen_string_literal: true

class AddPartialIndexPinnedUntil < ActiveRecord::Migration[6.1]
  disable_ddl_transaction!

  def change
    add_index :topics, :pinned_until,
      where: 'pinned_until IS NOT NULL',
      algorithm: :concurrently
  end
end
