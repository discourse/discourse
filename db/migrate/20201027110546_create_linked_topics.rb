# frozen_string_literal: true

class CreateLinkedTopics < ActiveRecord::Migration[6.0]
  def change
    create_table :linked_topics do |t|
      t.bigint :topic_id, null: false
      t.bigint :original_topic_id, null: false
      t.integer :sequence, null: false

      t.timestamps
    end

    add_index :linked_topics, %i[topic_id original_topic_id], unique: true
    add_index :linked_topics, %i[topic_id sequence], unique: true
  end
end
