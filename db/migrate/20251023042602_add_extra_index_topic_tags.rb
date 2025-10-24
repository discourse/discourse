# frozen_string_literal: true
class AddExtraIndexTopicTags < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    remove_index :topic_tags, %i[tag_id topic_id], if_exists: true
    add_index :topic_tags, %i[tag_id topic_id], unique: true, algorithm: :concurrently
  end
end
