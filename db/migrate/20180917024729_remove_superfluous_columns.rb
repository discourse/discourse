# frozen_string_literal: true

require "migration/column_dropper"
require "badge_posts_view_manager"

class RemoveSuperfluousColumns < ActiveRecord::Migration[5.2]
  DROPPED_COLUMNS = {
    user_profiles: %i[card_image_badge_id],
    categories: %i[logo_url background_url suppress_from_homepage],
    groups: %i[visible public alias_level],
    theme_fields: %i[target],
    user_stats: %i[first_topic_unread_at],
    topics: %i[
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
    ],
    users: %i[
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
      blocked
      silenced
      trust_level_locked
    ],
    user_auth_tokens: %i[legacy],
    user_options: %i[theme_key],
    themes: %i[key],
    email_logs: %i[topic_id reply_key skipped skipped_reason],
    posts: %i[vote_count],
  }

  def up
    BadgePostsViewManager.drop!

    DROPPED_COLUMNS.each { |table, columns| Migration::ColumnDropper.execute_drop(table, columns) }

    DB.exec "DROP FUNCTION IF EXISTS first_unread_topic_for(int)"

    BadgePostsViewManager.create!
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
