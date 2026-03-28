# frozen_string_literal: true

class CreateNestedTopics < ActiveRecord::Migration[8.0]
  def change
    create_table :nested_topics do |t|
      t.bigint :topic_id, null: false
      t.integer :pinned_post_number
      t.timestamps
    end

    add_index :nested_topics, :topic_id, unique: true

    add_column :category_settings, :nested_replies_default, :boolean, default: false, null: false
  end
end
