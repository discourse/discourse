# frozen_string_literal: true

class DeleteOldReminderTopicTimers < ActiveRecord::Migration[6.1]
  def up
    # following up from MigrateUserTopicTimersToBookmarkReminders,
    # these status type 5 topic timers are the reminder type which
    # have long been migrated to bookmark reminders
    DB.exec("DELETE FROM topic_timers WHERE status_type = 5")
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
