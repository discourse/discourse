# frozen_string_literal: true

class AddParticipantCountToTopics < ActiveRecord::Migration[4.2]
  def up
    add_column :topics, :participant_count, :integer, default: 1

    execute "UPDATE topics SET participant_count =
              (SELECT COUNT(DISTINCT p.user_id) FROM posts AS p WHERE p.topic_id = topics.id)"
  end

  def down
    remove_column :topics, :participant_count
  end

end
