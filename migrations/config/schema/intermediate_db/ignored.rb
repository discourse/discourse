# frozen_string_literal: true

Migrations::Database::Schema.ignored do
  # Plugins — all their tables and columns on core tables are auto-ignored via manifest
  plugin :automation, "Not migrated yet"
  plugin :chat, "Not migrated yet"
  plugin :discourse_adplugin, "Not migrated yet"
  plugin :discourse_ai, "Not migrated yet"
  plugin :discourse_assign, "Not migrated yet"
  plugin :discourse_calendar, "Not migrated yet"
  plugin :discourse_data_explorer, "Not migrated yet"
  plugin :discourse_gamification, "Not migrated yet"
  plugin :discourse_github, "Not migrated yet"
  plugin :discourse_oauth2_basic, "Not migrated yet"
  plugin :discourse_policy, "Not migrated yet"
  plugin :discourse_post_voting, "Not migrated yet"
  plugin :discourse_reactions, "Not migrated yet"
  plugin :discourse_rewind, "Not migrated yet"
  plugin :discourse_rss_polling, "Not migrated yet"
  plugin :discourse_solved, "Not migrated yet"
  plugin :discourse_subscriptions, "Not migrated yet"
  plugin :discourse_templates, "Not migrated yet"
  plugin :discourse_topic_voting, "Not migrated yet"
  plugin :poll, "Not migrated yet"

  # Core tables excluded from the intermediate database

  tables :allowed_pm_users,
         :anonymous_users,
         :ignored_users,
         :single_sign_on_records,
         :user_actions,
         :user_api_key_client_scopes,
         :user_api_key_clients,
         :user_api_key_scopes,
         :user_api_keys,
         :user_archived_messages,
         :user_associated_groups,
         :user_auth_token_logs,
         :user_auth_tokens,
         :user_avatars,
         :user_badges,
         :user_exports,
         :user_histories,
         :user_ip_address_histories,
         :user_notification_schedules,
         :user_open_ids,
         :user_passwords,
         :user_profile_views,
         :user_profiles,
         :user_required_fields_versions,
         :user_search_data,
         :user_second_factors,
         :user_security_keys,
         :user_stats,
         :user_statuses,
         :user_uploads,
         :user_visits,
         :user_warnings

  tables :draft_sequences,
         :drafts,
         :moved_posts,
         :post_action_types,
         :post_actions,
         :post_custom_fields,
         :post_details,
         :post_hotlinked_media,
         :post_localizations,
         :post_replies,
         :post_reply_keys,
         :post_revisions,
         :post_search_data,
         :post_stats,
         :post_timings,
         :posts,
         :quoted_posts,
         :shared_drafts

  tables :dismissed_topic_users,
         :linked_topics,
         :top_topics,
         :topic_custom_fields,
         :topic_embeds,
         :topic_groups,
         :topic_hot_scores,
         :topic_invites,
         :topic_link_clicks,
         :topic_links,
         :topic_localizations,
         :topic_search_data,
         :topic_thumbnails,
         :topic_timers,
         :topic_view_stats,
         :topic_views

  tables :category_featured_topics,
         :category_form_templates,
         :category_groups,
         :category_localizations,
         :category_posting_review_groups,
         :category_required_tag_groups,
         :category_search_data,
         :category_settings,
         :category_tag_groups,
         :category_tag_stats,
         :category_tags

  tables :group_archived_messages,
         :group_associated_groups,
         :group_category_notification_defaults,
         :group_custom_fields,
         :group_histories,
         :group_mentions,
         :group_requests,
         :group_tag_notification_defaults

  tables :child_themes,
         :color_scheme_colors,
         :color_schemes,
         :remote_themes,
         :theme_fields,
         :theme_modifier_sets,
         :theme_settings,
         :theme_settings_migrations,
         :theme_site_settings,
         :theme_svg_sprites,
         :theme_translation_overrides,
         :themes

  tables :incoming_domains, :incoming_emails, :incoming_links, :incoming_referers

  tables :reviewable_claimed_topics,
         :reviewable_histories,
         :reviewable_notes,
         :reviewable_scores,
         :reviewables

  tables :categories_web_hooks,
         :groups_web_hooks,
         :redelivering_webhook_events,
         :tags_web_hooks,
         :web_hook_event_types,
         :web_hook_event_types_hooks,
         :web_hook_events,
         :web_hook_events_daily_aggregates,
         :web_hooks

  tables :external_upload_stubs, :optimized_images, :optimized_videos, :upload_references, :uploads

  tables :admin_notices,
         :api_key_scopes,
         :api_keys,
         :application_requests,
         :ar_internal_metadata,
         :associated_groups,
         :backup_draft_posts,
         :backup_draft_topics,
         :backup_metadata,
         :badge_types,
         :bookmarks,
         :custom_emojis,
         :developers,
         :directory_columns,
         :directory_items,
         :do_not_disturb_timings,
         :email_change_requests,
         :email_logs,
         :email_tokens,
         :embeddable_host_tags,
         :embeddable_hosts,
         :flags,
         :form_templates,
         :given_daily_likes,
         :invited_groups,
         :invited_users,
         :invites,
         :javascript_caches,
         :message_bus,
         :notifications,
         :oauth2_user_infos,
         :onceoff_logs,
         :permalinks,
         :plugin_store_rows,
         :problem_check_trackers,
         :published_pages,
         :push_subscriptions,
         :scheduler_stats,
         :schema_migration_details,
         :schema_migrations,
         :screened_emails,
         :screened_ip_addresses,
         :screened_urls,
         :search_logs,
         :shelved_notifications,
         :sidebar_section_links,
         :sidebar_sections,
         :sidebar_urls,
         :site_setting_groups,
         :sitemaps,
         :skipped_email_logs,
         :stylesheet_cache,
         :summary_sections,
         :tag_localizations,
         :tag_search_data,
         :translation_overrides,
         :unsubscribe_keys,
         :upcoming_change_events,
         :watched_word_groups,
         :watched_words,
         :web_crawler_requests
end
