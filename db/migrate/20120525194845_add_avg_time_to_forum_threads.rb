# frozen_string_literal: true

class AddAvgTimeToForumThreads < ActiveRecord::Migration[4.2]
  def up
    add_column :forum_threads, :avg_time, :integer

    execute "update forum_threads SET avg_time = abs(random() * 1200)"
  end

  def down
    remove_column :forum_threads, :avg_time
  end

end
