# Delayed migration steps

require 'migration/table_dropper'
require 'migration/column_dropper'

Migration::ColumnDropper.drop(
  table: 'user_profiles',
  after_migration: 'DropUserCardBadgeColumns',
  columns: ['card_image_badge_id'],
  on_drop: ->() {
    STDERR.puts "Removing user_profiles column card_image_badge_id"
  },
  delay: 3600
)

Migration::ColumnDropper.drop(
  table: 'categories',
  after_migration: 'AddSuppressFromLatestToCategories',
  columns: ['logo_url', 'background_url', 'suppress_from_homepage'],
  on_drop: ->() {
    STDERR.puts 'Removing superflous categories columns!'
  }
)

Migration::ColumnDropper.drop(
  table: 'groups',
  after_migration: 'SplitAliasLevels',
  columns:  %w[visible public alias_level],
  on_drop: ->() {
    STDERR.puts 'Removing superflous visible group column!'
  }
)

Migration::ColumnDropper.drop(
  table: 'theme_fields',
  after_migration: 'AddUploadIdToThemeFields',
  columns: ['target'],
  on_drop: ->() {
    STDERR.puts 'Removing superflous theme_fields target column!'
  }
)

Migration::ColumnDropper.drop(
  table: 'user_stats',
  after_migration: 'DropUnreadTrackingColumns',
  columns: %w{
    first_topic_unread_at
  },
  on_drop: ->() {
    STDERR.puts "Removing superflous user stats columns!"
    DB.exec "DROP FUNCTION IF EXISTS first_unread_topic_for(int)"
  }
)

Migration::ColumnDropper.drop(
  table: 'topics',
  after_migration: 'DropVoteCountFromTopicsAndPosts',
  columns: %w{
    auto_close_at
    auto_close_user_id
    auto_close_started_at
    auto_close_based_on_last_post
    auto_close_hours
    inappropriate_count
    bookmark_count
    off_topic_count
    illegal_count
    notify_user_count
    last_unread_at
    vote_count
  },
  on_drop: ->() {
    STDERR.puts "Removing superflous topic columns!"
  }
)

VIEW_NAME = "badge_posts".freeze

def badge_posts_view_exists?
  sql = <<~SQL
  SELECT 1
  FROM pg_catalog.pg_views
  WHERE schemaname
  IN ('public')
  AND viewname = '#{VIEW_NAME}';
  SQL

  DB.exec(sql) == 1
end

Migration::ColumnDropper.drop(
  table: 'posts',
  after_migration: 'DropVoteCountFromTopicsAndPosts',
  columns: %w{
    vote_count
  },
  on_drop: ->() {
    STDERR.puts "Removing superflous post columns!"

    DB.exec("DROP VIEW #{VIEW_NAME}")
    raise "Failed to drop '#{VIEW_NAME}' view" if badge_posts_view_exists?
  },
  after_drop: -> () {
    sql = <<~SQL
    CREATE VIEW #{VIEW_NAME} AS
    SELECT p.*
    FROM posts p
    JOIN topics t ON t.id = p.topic_id
    JOIN categories c ON c.id = t.category_id
    WHERE c.allow_badges AND
          p.deleted_at IS NULL AND
          t.deleted_at IS NULL AND
          NOT c.read_restricted AND
          t.visible AND
          p.post_type IN (1,2,3)
    SQL

    DB.exec(sql)
    raise "Failed to create '#{VIEW_NAME}' view" unless badge_posts_view_exists?
  }
)

Migration::ColumnDropper.drop(
  table: 'users',
  after_migration: 'DropEmailFromUsers',
  columns: %w[
    email
    email_always
    mailing_list_mode
    email_digests
    email_direct
    email_private_messages
    external_links_in_new_tab
    enable_quoting
    dynamic_favicon
    disable_jump_reply
    edit_history_public
    automatically_unpin_topics
    digest_after_days
    auto_track_topics_after_msecs
    new_topic_duration_minutes
    last_redirected_to_top_at
    auth_token
    auth_token_updated_at
  ],
  on_drop: ->() {
    STDERR.puts 'Removing superflous users columns!'
  }
)

Migration::ColumnDropper.drop(
  table: 'users',
  after_migration: 'RenameBlockedSilence',
  columns: %w[
    blocked
  ],
  on_drop: ->() {
    STDERR.puts 'Removing user blocked column!'
  }
)

Migration::ColumnDropper.drop(
  table: 'users',
  after_migration: 'AddSilencedTillToUsers',
  columns: %w[
    silenced
  ],
  on_drop: ->() {
    STDERR.puts 'Removing user silenced column!'
  }
)

Migration::ColumnDropper.drop(
  table: 'users',
  after_migration: 'AddTrustLevelLocksToUsers',
  columns: %w[
    trust_level_locked
  ],
  on_drop: ->() {
    STDERR.puts 'Removing user trust_level_locked!'
  }
)

Migration::ColumnDropper.drop(
  table: 'user_auth_tokens',
  after_migration: 'RemoveLegacyAuthToken',
  columns: %w[
    legacy
  ],
  on_drop: ->() {
    STDERR.puts 'Removing user_auth_token legacy column!'
  }
)

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

Discourse.reset_active_record_cache
