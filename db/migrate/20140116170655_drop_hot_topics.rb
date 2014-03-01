class DropHotTopics < ActiveRecord::Migration
  def change
    drop_table :hot_topics
  end
end
