# frozen_string_literal: true

class CreateHotTopics < ActiveRecord::Migration[4.2]
  def change
    create_table :hot_topics, force: true do |t|
      t.integer :topic_id, null: false
      t.integer :category_id, null: true
      t.float :score, null: false
    end

    add_index :hot_topics, :topic_id, unique: true
    add_index :hot_topics, :score, order: 'desc'
  end
end
