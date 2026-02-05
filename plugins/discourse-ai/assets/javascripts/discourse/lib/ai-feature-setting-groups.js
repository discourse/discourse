export const AI_FEATURE_SETTING_GROUPS = {
  ai_helper: [
    {
      key: "access_permissions",
      titleKey:
        "discourse_ai.features.ai_helper.setting_groups.access_permissions",
      settings: [
        "ai_helper_enabled",
        "composer_ai_helper_allowed_groups",
        "post_ai_helper_allowed_groups",
        "ai_helper_allowed_in_pm",
      ],
    },
    {
      key: "enabled_features",
      titleKey:
        "discourse_ai.features.ai_helper.setting_groups.enabled_features",
      settings: ["ai_helper_enabled_features"],
    },
    {
      key: "automation",
      titleKey: "discourse_ai.features.ai_helper.setting_groups.automation",
      settings: [
        "ai_helper_automatic_chat_thread_title",
        "ai_helper_automatic_chat_thread_title_delay",
      ],
    },
    {
      key: "personas",
      titleKey: "discourse_ai.features.ai_helper.setting_groups.personas",
      settings: [
        "ai_helper_proofreader_persona",
        "ai_helper_title_suggestions_persona",
        "ai_helper_explain_persona",
        "ai_helper_post_illustrator_persona",
        "ai_helper_smart_dates_persona",
        "ai_helper_translator_persona",
        "ai_helper_markdown_tables_persona",
        "ai_helper_custom_prompt_persona",
        "ai_helper_image_caption_persona",
        "ai_helper_chat_thread_title_persona",
      ],
    },
  ],

  embeddings: [
    {
      key: "model_settings",
      titleKey:
        "discourse_ai.features.embeddings.setting_groups.model_settings",
      settings: [
        "ai_embeddings_enabled",
        "ai_embeddings_selected_model",
        "ai_embeddings_generate_for_pms",
      ],
    },
    {
      key: "related_topics",
      titleKey:
        "discourse_ai.features.embeddings.setting_groups.related_topics",
      settings: [
        "ai_embeddings_semantic_related_topics_enabled",
        "ai_embeddings_semantic_related_topics",
        "ai_embeddings_semantic_related_include_closed_topics",
        "ai_embeddings_semantic_related_age_penalty",
        "ai_embeddings_semantic_related_age_time_scale",
      ],
    },
    {
      key: "semantic_search",
      titleKey:
        "discourse_ai.features.embeddings.setting_groups.semantic_search",
      settings: [
        "ai_embeddings_semantic_search_enabled",
        "ai_embeddings_semantic_search_use_hyde",
        "ai_embeddings_semantic_quick_search_enabled",
        "ai_embeddings_semantic_search_hyde_persona",
      ],
    },
  ],

  bot: [
    {
      key: "settings",
      titleKey: "discourse_ai.features.bot.setting_groups.settings",
      settings: [
        "ai_bot_enabled",
        "ai_bot_enabled_llms",
        "ai_bot_enable_chat_warning",
      ],
    },
    {
      key: "access_control",
      titleKey: "discourse_ai.features.bot.setting_groups.access_control",
      settings: [
        "ai_bot_debugging_allowed_groups",
        "ai_bot_allowed_groups",
        "ai_bot_public_sharing_allowed_groups",
      ],
    },
    {
      key: "ui_settings",
      titleKey: "discourse_ai.features.bot.setting_groups.ui_settings",
      settings: ["ai_bot_add_to_header", "ai_bot_add_to_community_section"],
    },
    {
      key: "integrations",
      titleKey: "discourse_ai.features.bot.setting_groups.integrations",
      settings: ["ai_bot_github_access_token"],
    },
  ],

  summarization: [
    {
      key: "settings",
      titleKey: "discourse_ai.features.summarization.setting_groups.settings",
      settings: [
        "ai_summarization_enabled",
        "ai_summarization_persona",
        "ai_pm_summarization_allowed_groups",
      ],
    },
    {
      key: "gists",
      titleKey: "discourse_ai.features.summarization.setting_groups.gists",
      settings: ["ai_summary_gists_enabled", "ai_summary_gists_persona"],
    },
    {
      key: "backfill",
      titleKey: "discourse_ai.features.summarization.setting_groups.backfill",
      settings: [
        "ai_summary_backfill_topic_max_age_days",
        "ai_summary_backfill_maximum_topics_per_hour",
        "ai_summary_backfill_minimum_word_count",
      ],
    },
  ],

  search: [
    {
      key: "settings",
      titleKey: "discourse_ai.features.search.setting_groups.settings",
      settings: ["ai_discover_enabled", "ai_discover_persona"],
    },
  ],

  translation: [
    {
      key: "settings",
      titleKey: "discourse_ai.features.translation.setting_groups.settings",
      settings: ["ai_translation_enabled"],
    },
    {
      key: "personas",
      titleKey: "discourse_ai.features.translation.setting_groups.personas",
      settings: [
        "ai_translation_locale_detector_persona",
        "ai_translation_post_raw_translator_persona",
        "ai_translation_topic_title_translator_persona",
        "ai_translation_short_text_translator_persona",
      ],
    },
    {
      key: "backfill_and_limits",
      titleKey:
        "discourse_ai.features.translation.setting_groups.backfill_and_limits",
      settings: [
        "ai_translation_backfill_hourly_rate",
        "ai_translation_backfill_limit_to_public_content",
        "ai_translation_max_post_length",
        "ai_translation_backfill_max_age_days",
        "ai_translation_max_tokens_multiplier",
        "ai_translation_verbose_logs",
      ],
    },
  ],

  discord: [
    {
      key: "settings",
      titleKey: "discourse_ai.features.discord.setting_groups.settings",
      settings: [
        "ai_discord_search_enabled",
        "ai_discord_search_mode",
        "ai_discord_search_persona",
      ],
    },
    {
      key: "discord_configuration",
      titleKey:
        "discourse_ai.features.discord.setting_groups.discord_configuration",
      settings: [
        "ai_discord_app_id",
        "ai_discord_app_public_key",
        "ai_discord_allowed_guilds",
      ],
    },
  ],

  inference: [
    {
      key: "settings",
      titleKey: "discourse_ai.features.inference.setting_groups.settings",
      settings: ["inferred_concepts_enabled"],
    },
    {
      key: "topic_criteria",
      titleKey: "discourse_ai.features.inference.setting_groups.topic_criteria",
      settings: [
        "inferred_concepts_background_match",
        "inferred_concepts_daily_topics_limit",
        "inferred_concepts_min_posts",
        "inferred_concepts_min_likes",
        "inferred_concepts_min_views",
        "inferred_concepts_lookback_days",
      ],
    },
    {
      key: "post_criteria",
      titleKey: "discourse_ai.features.inference.setting_groups.post_criteria",
      settings: [
        "inferred_concepts_daily_posts_limit",
        "inferred_concepts_post_min_likes",
      ],
    },
    {
      key: "personas",
      titleKey: "discourse_ai.features.inference.setting_groups.personas",
      settings: [
        "inferred_concepts_generate_persona",
        "inferred_concepts_match_persona",
        "inferred_concepts_deduplicate_persona",
      ],
    },
  ],
};

export function getSettingGroupsForFeature(moduleName) {
  return AI_FEATURE_SETTING_GROUPS[moduleName] || [];
}
