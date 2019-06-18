# frozen_string_literal: true

class AddRankToCategoryFeaturedTopics < ActiveRecord::Migration[4.2]
  def change
    add_column :category_featured_topics, :rank, :integer, default: 0, null: false
    add_index :category_featured_topics, [:category_id, :rank]
  end
end
