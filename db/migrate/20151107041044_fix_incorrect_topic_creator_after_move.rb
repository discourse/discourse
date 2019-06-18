# frozen_string_literal: true

class FixIncorrectTopicCreatorAfterMove < ActiveRecord::Migration[4.2]
  def up
    execute "UPDATE topics SET user_id = p.user_id
             FROM posts p
             WHERE p.topic_id = topics.id AND
              p.post_number = 1 AND
              p.user_id <> topics.user_id"
  end

  def down
  end
end
