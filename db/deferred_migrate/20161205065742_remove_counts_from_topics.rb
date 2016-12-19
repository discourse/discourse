class RemoveCountsFromTopics < ActiveRecord::Migration
  def up
    %w{
      inappropriate_count
      bookmark_count
      off_topic_count
      illegal_count
      notify_user_count
    }.each do |column|
      Topic.exec_sql("ALTER TABLE topics DROP COLUMN IF EXISTS #{column}")
    end
  end

  def down
    add_column :topics, :inappropriate_count, :integer
    add_column :topics, :bookmark_count, :integer
    add_column :topics, :off_topic_count, :integer
    add_column :topics, :illegal_count, :integer
    add_column :topics, :notify_user_count, :integer
  end
end
