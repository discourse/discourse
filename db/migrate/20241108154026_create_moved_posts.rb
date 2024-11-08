# frozen_string_literal: true

class CreateMovedPosts < ActiveRecord::Migration[7.1]
  def change
    create_table :moved_posts do |t|
      t.bigint :old_topic_id, null: true, index: true
      t.bigint :old_post_id, null: true, index: true
      t.bigint :old_post_number, null: true, index: true
      t.bigint :new_topic_id, null: false, index: true
      t.string :new_topic_title, null: false, index: false
      t.bigint :new_post_id, null: false, index: true
      t.bigint :new_post_number, null: false, index: false
      t.boolean :created_new_topic, null: false, default: false
      t.timestamps
    end
  end
end
