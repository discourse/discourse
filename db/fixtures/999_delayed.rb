# Delayed migration steps

require 'table_migration_helper'

TableMigrationHelper.delayed_drop(
  old_name: 'topic_status_updates',
  new_name: 'topic_timers',
  after_migration: 'RenameTopicStatusUpdatesToTopicTimers',
  on_drop: ->() {
    STDERR.puts "Dropping topic_status_updates. It was moved to topic_timers."
  }
)
