# frozen_string_literal: true

require 'migration/table_dropper'

class CreateTopicStatusUpdatesAgain < ActiveRecord::Migration[4.2]
  def up
    create_table :topic_status_updates do |t|
      t.datetime :execute_at, null: false
      t.integer :status_type, null: false
      t.integer :user_id, null: false
      t.integer :topic_id, null: false
      t.boolean :based_on_last_post, null: false, default: false
      t.datetime :deleted_at
      t.integer :deleted_by_id
      t.timestamps null: false
      t.integer :category_id
    end

    Migration::TableDropper.read_only_table('topic_status_updates')
  end

  def down
    drop_table :topic_status_updates
  end
end
