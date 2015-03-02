class AddPinnedIndexes < ActiveRecord::Migration
  def change
    add_index :topics, :pinned_globally, where: 'pinned_globally'
    add_index :topics, :pinned_at, where: 'pinned_at IS NOT NULL'
  end
end
