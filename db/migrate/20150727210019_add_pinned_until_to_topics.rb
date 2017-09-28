class AddPinnedUntilToTopics < ActiveRecord::Migration[4.2]
  def change
    add_column :topics, :pinned_until, :datetime, null: true
  end
end
