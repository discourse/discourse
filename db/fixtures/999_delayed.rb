# Delayed migration steps

require 'migration/table_dropper'

Migration::TableDropper.delayed_rename(
  old_name: 'topic_status_updates',
  new_name: 'topic_timers',
  after_migration: 'RenameTopicStatusUpdatesToTopicTimers',
  on_drop: ->() {
    STDERR.puts "Dropping topic_status_updates. It was moved to topic_timers."
  }
)

Migration::TableDropper.delayed_drop(
  table_name: 'category_featured_users',
  after_migration: 'DropUnusedTables',
  on_drop: ->() {
    STDERR.puts "Dropping category_featured_users. It isn't used anymore."
  }
)

Migration::TableDropper.delayed_drop(
  table_name: 'versions',
  after_migration: 'DropUnusedTables',
  on_drop: ->() {
    STDERR.puts "Dropping versions. It isn't used anymore."
  }
)

Migration::ColumnDropper.drop(
  table: 'user_profiles',
  after_migration: 'DropUserCardBadgeColumns',
  columns: ['card_image_badge_id'],
  on_drop: ->() {
    STDERR.puts "Removing user_profiles column card_image_badge_id"
  },
  delay: 3600
)
