class AddRankToCategoryFeaturedTopics < ActiveRecord::Migration
  def change
    add_column :category_featured_topics, :rank, :integer, default: 0, null: false
    add_index :category_featured_topics, [:category_id, :rank]
  end
end
