# frozen_string_literal: true

class AddTopicColumnsBack < ActiveRecord::Migration[4.2]

  # This really sucks big time, we have no use for these columns yet can not remove them
  # if we remove them then sites will be down during migration

  def up
    add_column :topics, :bookmark_count, :int
     add_column :topics, :off_topic_count, :int
     add_column :topics, :illegal_count, :int
     add_column :topics, :inappropriate_count, :int
     add_column :topics, :notify_user_count, :int
  end

  def down
    remove_column :topics, :bookmark_count
     remove_column :topics, :off_topic_count
     remove_column :topics, :illegal_count
     remove_column :topics, :inappropriate_count
     remove_column :topics, :notify_user_count
  end
end
