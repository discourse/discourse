class RenameTopicStatusUpdatesToTopicTimers < ActiveRecord::Migration
  def change
    rename_table :topic_status_updates, :topic_timers
  end
end
