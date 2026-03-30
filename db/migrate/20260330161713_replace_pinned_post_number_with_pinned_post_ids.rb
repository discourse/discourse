# frozen_string_literal: true

class ReplacePinnedPostNumberWithPinnedPostIds < ActiveRecord::Migration[8.0]
  def up
    add_column :nested_topics, :pinned_post_ids, :bigint, array: true, default: [], null: false

    execute <<~SQL
      UPDATE nested_topics
      SET pinned_post_ids = ARRAY[p.id]
      FROM posts p
      WHERE p.topic_id = nested_topics.topic_id
        AND p.post_number = nested_topics.pinned_post_number
        AND nested_topics.pinned_post_number IS NOT NULL
    SQL
  end

  def down
    remove_column :nested_topics, :pinned_post_ids
  end
end
