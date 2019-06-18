# frozen_string_literal: true

class AddPinnedIndexes < ActiveRecord::Migration[4.2]
  def change
    add_index :topics, :pinned_globally, where: 'pinned_globally'
    add_index :topics, :pinned_at, where: 'pinned_at IS NOT NULL'
  end
end
