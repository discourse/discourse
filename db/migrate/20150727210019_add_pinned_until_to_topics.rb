class AddPinnedUntilToTopics < ActiveRecord::Migration
  def change
    add_column :topics, :pinned_until, :datetime, null: true
  end
end
