# frozen_string_literal: true

class DropDeprecatedColumns < ActiveRecord::Migration[7.0]
  DROPPED_COLUMNS = {
    categories: %i[suppress_from_latest required_tag_group_id min_tags_from_required_group],
    directory_columns: %i[automatic],
    email_tokens: %i[token],
    embeddable_hosts: %i[path_whitelist],
    groups: %i[flair_url],
    invites: %i[user_id redeemed_at],
    posts: %i[avg_time image_url],
    tags: %i[topic_count],
    topic_users: %i[highest_seen_post_number],
    topics: %i[avg_time image_url],
    user_api_keys: %i[scopes],
    user_options: %i[disable_jump_reply sidebar_list_destination],
    user_profiles: %i[badge_granted_title],
    user_stats: %i[topic_reply_count],
  }

  def up
    DROPPED_COLUMNS.each { |table, columns| Migration::ColumnDropper.execute_drop(table, columns) }
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
