class RenameTopicStatusUpdatesToTopicTimers < ActiveRecord::Migration[4.2]
  def change
    rename_table :topic_status_updates, :topic_timers
  end
end
