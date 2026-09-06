# frozen_string_literal: true

class CreateCategoryActivityDailyRollups < ActiveRecord::Migration[8.0]
  def change
    create_table :category_activity_daily_rollups do |t|
      t.date :date, null: false
      t.integer :category_id, null: false
      t.integer :topics, null: false, default: 0
      t.integer :posts, null: false, default: 0
      t.bigint :page_views, null: false, default: 0
    end

    add_index :category_activity_daily_rollups, %i[date category_id], unique: true
  end
end
