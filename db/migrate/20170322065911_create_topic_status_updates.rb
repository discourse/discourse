# frozen_string_literal: true

class CreateTopicStatusUpdates < ActiveRecord::Migration[4.2]
  def change
    create_table :topic_status_updates do |t|
      t.datetime :execute_at, null: false
      t.integer :status_type, null: false
      t.integer :user_id, null: false
      t.integer :topic_id, null: false
      t.boolean :based_on_last_post, null: false, default: false
      t.datetime :deleted_at
      t.integer :deleted_by_id
      t.timestamps null: false
    end

    add_index :topic_status_updates, :user_id
  end
end
