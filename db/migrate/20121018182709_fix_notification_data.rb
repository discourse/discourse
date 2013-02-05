class FixNotificationData < ActiveRecord::Migration
  def up
    execute "UPDATE notifications SET data = replace(data, 'thread_title', 'topic_title')"
  end

  def down
  end
end
