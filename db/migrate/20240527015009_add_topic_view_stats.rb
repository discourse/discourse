# frozen_string_literal: true

class AddTopicViewStats < ActiveRecord::Migration[7.0]
  def change
    create_table :topic_view_stats do |t|
      t.integer :topic_id, null: false
      t.date :viewed_at, null: false
      t.integer :anonymous_views, default: 0, null: false
      t.integer :logged_in_views, default: 0, null: false
    end

    add_index :topic_view_stats, %i[topic_id viewed_at], unique: true
    add_index :topic_view_stats, %i[viewed_at topic_id]
  end
end
