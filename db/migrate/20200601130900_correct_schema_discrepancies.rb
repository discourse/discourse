# frozen_string_literal: true

class CorrectSchemaDiscrepancies < ActiveRecord::Migration[6.0]
  disable_ddl_transaction!

  def up
    timestamp_columns = %w[
      category_tag_groups.created_at
      category_tag_groups.updated_at
      category_tags.created_at
      category_tags.updated_at
      child_themes.created_at
      child_themes.updated_at
      embeddable_hosts.created_at
      embeddable_hosts.updated_at
      group_archived_messages.created_at
      group_archived_messages.updated_at
      group_mentions.created_at
      group_mentions.updated_at
      muted_users.created_at
      muted_users.updated_at
      permalinks.created_at
      permalinks.updated_at
      post_stats.created_at
      post_stats.updated_at
      remote_themes.created_at
      remote_themes.updated_at
      stylesheet_cache.created_at
      stylesheet_cache.updated_at
      tag_group_memberships.created_at
      tag_group_memberships.updated_at
      tag_groups.created_at
      tag_groups.updated_at
      tag_users.created_at
      tag_users.updated_at
      tags.created_at
      tags.updated_at
      theme_fields.created_at
      theme_fields.updated_at
      topic_tags.created_at
      topic_tags.updated_at
      topic_timers.created_at
      topic_timers.updated_at
      unsubscribe_keys.created_at
      unsubscribe_keys.updated_at
      user_api_keys.created_at
      user_api_keys.updated_at
      user_archived_messages.created_at
      user_archived_messages.updated_at
      user_auth_tokens.created_at
      user_auth_tokens.updated_at
      user_emails.created_at
      user_emails.updated_at
      user_exports.created_at
      user_exports.updated_at
      user_field_options.created_at
      user_field_options.updated_at
      user_fields.created_at
      user_fields.updated_at
      user_warnings.created_at
      user_warnings.updated_at
      watched_words.created_at
      watched_words.updated_at
      web_hook_events.created_at
      web_hook_events.updated_at
      web_hooks.created_at
      web_hooks.updated_at
    ]

    char_limit_columns = %w[
      badge_groupings.name
      badge_types.name
      badges.icon
      badges.name
      categories.email_in
      categories.slug
      color_scheme_colors.hex
      color_scheme_colors.name
      color_schemes.name
      draft_sequences.draft_key
      drafts.draft_key
      email_logs.email_type
      email_logs.to_address
      email_tokens.email
      email_tokens.token
      embeddable_hosts.host
      github_user_infos.screen_name
      groups.name
      groups.title
      invites.email
      message_bus.context
      message_bus.name
      oauth2_user_infos.email
      oauth2_user_infos.name
      oauth2_user_infos.provider
      oauth2_user_infos.uid
      optimized_images.url
      plugin_store_rows.key
      plugin_store_rows.plugin_name
      plugin_store_rows.type_name
      post_details.key
      post_details.value
      post_search_data.locale
      schema_migrations.version
      screened_emails.email
      screened_urls.domain
      screened_urls.url
      single_sign_on_records.external_email
      single_sign_on_records.external_id
      single_sign_on_records.external_name
      single_sign_on_records.external_username
      site_settings.name
      stylesheet_cache.digest
      stylesheet_cache.target
      themes.name
      topic_links.title
      topic_search_data.locale
      topics.archetype
      topics.slug
      topics.subtype
      topics.title
      uploads.original_filename
      uploads.url
      user_exports.file_name
      user_field_options.value
      user_fields.description
      user_fields.field_type
      user_fields.name
      user_histories.context
      user_histories.custom_type
      user_histories.email
      user_histories.ip_address
      user_open_ids.email
      user_open_ids.url
      user_profiles.location
      user_profiles.website
      users.name
      users.title
    ]

    float_default_columns = %w[
      top_topics.all_score
      top_topics.daily_score
      top_topics.monthly_score
      top_topics.weekly_score
      top_topics.yearly_score
    ]

    other_default_columns = %w[categories.color topic_search_data.topic_id]

    lookup_sql =
      (timestamp_columns + char_limit_columns + float_default_columns + other_default_columns)
        .map do |ref|
          table, column = ref.split(".")
          "(table_name='#{table}' AND column_name='#{column}')"
        end
        .join(" OR ")

    raw_info = DB.query_hash <<~SQL
      SELECT table_name, column_name, is_nullable, character_maximum_length, column_default
      FROM information_schema.columns
      WHERE table_schema='public'
      AND (
        #{lookup_sql}
      )
    SQL

    schema_hash = {}

    raw_info.each { |row| schema_hash["#{row["table_name"]}.#{row["column_name"]}"] = row }

    # In the past, rails changed the default behavior for timestamp columns
    # This only affects older discourse installations
    # This migration will make old database schemas match modern behavior
    timestamp_columns.each do |ref|
      current_value = schema_hash[ref]["is_nullable"]
      next if current_value == "NO"

      table, column = ref.split(".")

      # There shouldn't be any null values - rails inserts timestamps automatically
      # But just in case, set them to now() if there are any nulls
      DB.exec <<~SQL
        UPDATE #{table} SET #{column} = now() WHERE #{column} IS NULL
      SQL

      DB.exec <<~SQL
        ALTER TABLE #{table} ALTER COLUMN #{column} SET NOT NULL
      SQL
    end

    # In the past, rails changed the default behavior for varchar columns
    # This only affects older discourse installations
    # This migration removes the character limits from columns, so that they match modern behavior
    char_limit_columns.each do |ref|
      current_value = schema_hash[ref]["character_maximum_length"]
      next if current_value == nil
      table, column = ref.split(".")

      DB.exec <<~SQL
        ALTER TABLE #{table} ALTER COLUMN #{column} TYPE varchar
      SQL
    end

    # In the past, rails changed the default behavior for float columns
    # This only affects older discourse installations
    # This migration updates the default values, so that they match modern behavior
    float_default_columns.each do |ref|
      current_value = schema_hash[ref]["column_default"]
      next if current_value == "0.0"
      table, column = ref.split(".")

      DB.exec <<~SQL
        ALTER TABLE #{table} ALTER COLUMN #{column} SET DEFAULT 0.0
      SQL
    end

    # Category color default was changed in https://github.com/discourse/discourse/commit/faf09bb8c80fcb28b132a5a644ac689cc9abffc2
    # But should have been added in a new migration
    if schema_hash["categories.color"]["column_default"] != "'0088CC'::character varying"
      DB.exec <<~SQL
        ALTER TABLE categories ALTER COLUMN color SET DEFAULT '0088CC'
      SQL
    end

    # Older sites have a default value like nextval('topic_search_data_topic_id_seq'::regclass)
    # Modern sites do not. This is likely caused by another historical change in rails
    DB.exec <<~SQL if schema_hash["topic_search_data.topic_id"]["column_default"] != nil
        ALTER TABLE topic_search_data ALTER COLUMN topic_id SET DEFAULT NULL
      SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
