# frozen_string_literal: true

class CreateTopicGroupTable < ActiveRecord::Migration[5.2]
  def change
    create_table :topic_groups do |t|
      t.integer :group_id, null: false
      t.integer :topic_id, null: false
      t.integer :last_read_post_number, null: false, default: 0
      t.timestamps null: false
    end

    add_index :topic_groups, %i[group_id topic_id], unique: true
  end
end
