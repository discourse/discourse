# frozen_string_literal: true

class MoveColumnsToUserStats < ActiveRecord::Migration[4.2]
  def up
    add_column :user_stats, :topics_entered, :integer, default: 0, null: false
    add_column :user_stats, :time_read, :integer, default: 0, null: false
    add_column :user_stats, :days_visited, :integer, default: 0, null: false
    add_column :user_stats, :posts_read_count, :integer, default: 0, null: false
    add_column :user_stats, :likes_given, :integer, default: 0, null: false
    add_column :user_stats, :likes_received, :integer, default: 0, null: false
    add_column :user_stats, :topic_reply_count, :integer, default: 0, null: false

    execute 'UPDATE user_stats s
              SET topics_entered = u.topics_entered,
                  time_read = u.time_read,
                  days_visited = u.days_visited,
                  posts_read_count = u.posts_read_count,
                  likes_given = u.likes_given,
                  likes_received = u.likes_received,
                  topic_reply_count = u.topic_reply_count
              FROM users u WHERE u.id = s.user_id
    '

    remove_column :users, :topics_entered
    remove_column :users, :time_read
    remove_column :users, :days_visited
    remove_column :users, :posts_read_count
    remove_column :users, :likes_given
    remove_column :users, :likes_received
    remove_column :users, :topic_reply_count
  end

  def down
    add_column :users, :topics_entered, :integer
    add_column :users, :time_read, :integer
    add_column :users, :days_visited, :integer
    add_column :users, :posts_read_count, :integer
    add_column :users, :likes_given, :integer
    add_column :users, :likes_received, :integer
    add_column :users, :topic_reply_count, :integer

    execute 'UPDATE users s
              SET topics_entered = u.topics_entered,
                  time_read = u.time_read,
                  days_visited = u.days_visited,
                  posts_read_count = u.posts_read_count,
                  likes_given = u.likes_given,
                  likes_received = u.likes_received,
                  topic_reply_count = u.topic_reply_count
              FROM user_stats u WHERE s.id = u.user_id
    '

    remove_column :user_stats, :topics_entered
    remove_column :user_stats, :time_read
    remove_column :user_stats, :days_visited
    remove_column :user_stats, :posts_read_count
    remove_column :user_stats, :likes_given
    remove_column :user_stats, :likes_received
    remove_column :user_stats, :topic_reply_count
  end
end
