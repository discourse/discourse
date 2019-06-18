# frozen_string_literal: true

class AddIndexTopicIdPercentRankOnPosts < ActiveRecord::Migration[5.2]
  def up
    add_index :posts, [:topic_id, :percent_rank], order: { percent_rank: :asc }
  end

  def down
    remove_index :posts, [:topic_id, :percent_rank]
  end
end
