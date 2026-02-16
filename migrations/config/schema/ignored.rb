# frozen_string_literal: true

Migrations::Database::Schema.ignored do
  # Tables excluded from the intermediate database
  # TODO: Add reasons for each table or group

  tables :user_actions,
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
         :user_chat_channel_memberships,
         :user_chat_thread_memberships,
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
         :user_warnings,
         reason: "TODO: add reason"

  tables :discourse_automation_automations,
         :discourse_automation_fields,
         :discourse_automation_pending_automations,
         :discourse_automation_pending_pms,
         :discourse_automation_stats,
         :discourse_automation_user_global_notices,
         :discourse_calendar_disabled_holidays,
         :discourse_calendar_post_event_dates,
         :discourse_post_event_events,
         :discourse_post_event_invitees,
         :discourse_reactions_reaction_users,
         :discourse_reactions_reactions,
         :discourse_rss_polling_rss_feeds,
         :discourse_solved_solved_topics,
         :discourse_subscriptions_customers,
         :discourse_subscriptions_products,
         :discourse_subscriptions_subscriptions,
         :discourse_templates_usage_count,
         reason: "TODO: add reason"

  tables :post_action_types,
         :post_actions,
         :post_custom_fields,
         :post_custom_prompts,
         :post_details,
         :post_hotlinked_media,
         :post_localizations,
         :post_policies,
         :post_policy_groups,
         :post_replies,
         :post_reply_keys,
         :post_revisions,
         :post_search_data,
         :post_stats,
         :post_timings,
         :post_voting_comment_custom_fields,
         :post_voting_comments,
         :post_voting_votes,
         reason: "TODO: add reason"

  tables :chat_channel_archives,
         :chat_channel_custom_fields,
         :chat_channels,
         :chat_drafts,
         :chat_mention_notifications,
         :chat_mentions,
         :chat_message_custom_fields,
         :chat_message_custom_prompts,
         :chat_message_interactions,
         :chat_message_links,
         :chat_message_reactions,
         :chat_message_revisions,
         :chat_message_search_data,
         :chat_messages,
         :chat_thread_custom_fields,
         :chat_threads,
         :chat_webhook_events,
         reason: "TODO: add reason"

  tables :topic_custom_fields,
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
         :topic_views,
         :topic_voting_category_settings,
         :topic_voting_topic_vote_count,
         :topic_voting_votes,
         reason: "TODO: add reason"

  tables :ai_api_audit_logs,
         :ai_api_request_stats,
         :ai_artifact_key_values,
         :ai_artifact_versions,
         :ai_artifacts,
         :ai_document_fragments_embeddings,
         :ai_moderation_settings,
         :ai_personas,
         :ai_posts_embeddings,
         :ai_secrets,
         :ai_spam_logs,
         :ai_summaries,
         :ai_tools,
         :ai_topics_embeddings,
         reason: "TODO: add reason"

  tables :category_featured_topics,
         :category_form_templates,
         :category_groups,
         :category_localizations,
         :category_required_tag_groups,
         :category_search_data,
         :category_settings,
         :category_tag_groups,
         :category_tag_stats,
         :category_tags,
         reason: "TODO: add reason"

  tables :group_archived_messages,
         :group_associated_groups,
         :group_category_notification_defaults,
         :group_custom_fields,
         :group_histories,
         :group_mentions,
         :group_requests,
         :group_tag_notification_defaults,
         reason: "TODO: add reason"

  tables :theme_fields,
         :theme_modifier_sets,
         :theme_settings,
         :theme_settings_migrations,
         :theme_site_settings,
         :theme_svg_sprites,
         :theme_translation_overrides,
         reason: "TODO: add reason"

  tables :llm_credit_allocations,
         :llm_credit_daily_usages,
         :llm_feature_credit_costs,
         :llm_models,
         :llm_quota_usages,
         :llm_quotas,
         reason: "TODO: add reason"

  tables :ad_plugin_house_ads,
         :ad_plugin_house_ads_categories,
         :ad_plugin_house_ads_groups,
         :ad_plugin_house_ads_routes,
         :ad_plugin_impressions,
         reason: "TODO: add reason"

  tables :incoming_chat_webhooks,
         :incoming_domains,
         :incoming_emails,
         :incoming_links,
         :incoming_referers,
         reason: "TODO: add reason"

  tables :reviewable_action_logs,
         :reviewable_claimed_topics,
         :reviewable_histories,
         :reviewable_notes,
         :reviewable_scores,
         reason: "TODO: add reason"

  tables :web_hook_event_types,
         :web_hook_event_types_hooks,
         :web_hook_events,
         :web_hook_events_daily_aggregates,
         :web_hooks,
         reason: "TODO: add reason"

  tables :backup_draft_posts, :backup_draft_topics, :backup_metadata, reason: "TODO: add reason"

  tables :email_change_requests, :email_logs, :email_tokens, reason: "TODO: add reason"

  tables :gamification_leaderboards,
         :gamification_score_events,
         :gamification_scores,
         reason: "TODO: add reason"

  tables :inferred_concept_posts,
         :inferred_concept_topics,
         :inferred_concepts,
         reason: "TODO: add reason"

  tables :screened_emails, :screened_ip_addresses, :screened_urls, reason: "TODO: add reason"

  tables :sidebar_section_links, :sidebar_sections, :sidebar_urls, reason: "TODO: add reason"

  tables :api_key_scopes, :api_keys, reason: "TODO: add reason"

  tables :color_scheme_colors, :color_schemes, reason: "TODO: add reason"

  tables :data_explorer_queries, :data_explorer_query_groups, reason: "TODO: add reason"

  tables :direct_message_channels, :direct_message_users, reason: "TODO: add reason"

  tables :directory_columns, :directory_items, reason: "TODO: add reason"

  tables :embeddable_host_tags, :embeddable_hosts, reason: "TODO: add reason"

  tables :github_commits, :github_repos, reason: "TODO: add reason"

  tables :invited_groups, :invited_users, reason: "TODO: add reason"

  tables :optimized_images, :optimized_videos, reason: "TODO: add reason"

  tables :poll_options, :poll_votes, reason: "TODO: add reason"

  tables :schema_migration_details, :schema_migrations, reason: "TODO: add reason"

  tables :shared_ai_conversations, :shared_drafts, reason: "TODO: add reason"

  tables :tag_localizations, :tag_search_data, reason: "TODO: add reason"

  tables :watched_word_groups, :watched_words, reason: "TODO: add reason"

  table :admin_notices, "TODO: add reason"

  table :allowed_pm_users, "TODO: add reason"

  table :anonymous_users, "TODO: add reason"

  table :application_requests, "TODO: add reason"

  table :ar_internal_metadata, "TODO: add reason"

  table :assignments, "TODO: add reason"

  table :associated_groups, "TODO: add reason"

  table :badge_types, "TODO: add reason"

  table :bookmarks, "TODO: add reason"

  table :calendar_events, "TODO: add reason"

  table :categories_web_hooks, "TODO: add reason"

  table :child_themes, "TODO: add reason"

  table :classification_results, "TODO: add reason"

  table :completion_prompts, "TODO: add reason"

  table :custom_emojis, "TODO: add reason"

  table :developers, "TODO: add reason"

  table :dismissed_topic_users, "TODO: add reason"

  table :do_not_disturb_timings, "TODO: add reason"

  table :draft_sequences, "TODO: add reason"

  table :drafts, "TODO: add reason"

  table :embedding_definitions, "TODO: add reason"

  table :external_upload_stubs, "TODO: add reason"

  table :flags, "TODO: add reason"

  table :form_templates, "TODO: add reason"

  table :given_daily_likes, "TODO: add reason"

  table :groups_web_hooks, "TODO: add reason"

  table :ignored_users, "TODO: add reason"

  table :invites, "TODO: add reason"

  table :javascript_caches, "TODO: add reason"

  table :linked_topics, "TODO: add reason"

  table :message_bus, "TODO: add reason"

  table :model_accuracies, "TODO: add reason"

  table :moved_posts, "TODO: add reason"

  table :notifications, "TODO: add reason"

  table :oauth2_user_infos, "TODO: add reason"

  table :onceoff_logs, "TODO: add reason"

  table :permalinks, "TODO: add reason"

  table :plugin_store_rows, "TODO: add reason"

  table :policy_users, "TODO: add reason"

  table :polls, "TODO: add reason"

  table :posts, "TODO: add reason"

  table :problem_check_trackers, "TODO: add reason"

  table :published_pages, "TODO: add reason"

  table :push_subscriptions, "TODO: add reason"

  table :quoted_posts, "TODO: add reason"

  table :rag_document_fragments, "TODO: add reason"

  table :redelivering_webhook_events, "TODO: add reason"

  table :remote_themes, "TODO: add reason"

  table :reviewables, "TODO: add reason"

  table :scheduler_stats, "TODO: add reason"

  table :search_logs, "TODO: add reason"

  table :shelved_notifications, "TODO: add reason"

  table :silenced_assignments, "TODO: add reason"

  table :single_sign_on_records, "TODO: add reason"

  table :site_setting_groups, "TODO: add reason"

  table :sitemaps, "TODO: add reason"

  table :skipped_email_logs, "TODO: add reason"

  table :stylesheet_cache, "TODO: add reason"

  table :summary_sections, "TODO: add reason"

  table :tags_web_hooks, "TODO: add reason"

  table :themes, "TODO: add reason"

  table :top_topics, "TODO: add reason"

  table :translation_overrides, "TODO: add reason"

  table :unsubscribe_keys, "TODO: add reason"

  table :upcoming_change_events, "TODO: add reason"

  table :upload_references, "TODO: add reason"

  table :uploads, "TODO: add reason"

  table :web_crawler_requests, "TODO: add reason"
end
