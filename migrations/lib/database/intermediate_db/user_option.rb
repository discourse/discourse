# frozen_string_literal: true

# This file is auto-generated from the IntermediateDB schema. To make changes,
# update the "config/intermediate_db.yml" configuration file and then run
# `bin/cli schema generate` to regenerate this file.

module Migrations::Database::IntermediateDB
  module UserOption
    SQL = <<~SQL
      INSERT INTO user_options (
        user_id,
        ai_search_discoveries,
        allow_private_messages,
        auto_image_caption,
        auto_track_topics_after_msecs,
        automatically_unpin_topics,
        bookmark_auto_delete_preference,
        chat_email_frequency,
        chat_enabled,
        chat_header_indicator_preference,
        chat_quick_reaction_type,
        chat_quick_reactions_custom,
        chat_send_shortcut,
        chat_separate_sidebar_mode,
        chat_sound,
        color_scheme_id,
        composition_mode,
        dark_scheme_id,
        default_calendar,
        digest_after_minutes,
        dismissed_channel_retention_reminder,
        dismissed_dm_retention_reminder,
        dynamic_favicon,
        email_digests,
        email_in_reply_to,
        email_level,
        email_messages_level,
        email_previous_replies,
        enable_allowed_pm_users,
        enable_defer,
        enable_markdown_monospace_font,
        enable_quoting,
        enable_smart_lists,
        external_links_in_new_tab,
        hide_presence,
        hide_profile,
        hide_profile_and_presence,
        homepage_id,
        ignore_channel_wide_mention,
        include_tl0_in_digests,
        interface_color_mode,
        last_redirected_to_top_at,
        like_notification_frequency,
        mailing_list_mode,
        mailing_list_mode_frequency,
        new_topic_duration_minutes,
        notification_level_when_assigned,
        notification_level_when_replying,
        oldest_search_log_date,
        only_chat_push_notifications,
        policy_email_frequency,
        seen_popups,
        show_thread_title_prompts,
        sidebar_link_to_filtered_list,
        sidebar_show_count_of_new_items,
        skip_new_user_tips,
        text_size_key,
        text_size_seq,
        theme_ids,
        theme_key_seq,
        timezone,
        title_count_mode_key,
        topics_unread_when_closed,
        watched_precedence_over_muted
      )
      VALUES (
        ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?,
        ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?,
        ?, ?, ?, ?
      )
    SQL
    private_constant :SQL

    # Creates a new `user_options` record in the IntermediateDB.
    #
    # @param user_id                                [Integer, String]
    # @param ai_search_discoveries                  [Boolean, nil]
    # @param allow_private_messages                 [Boolean, nil]
    # @param auto_image_caption                     [Boolean, nil]
    # @param auto_track_topics_after_msecs          [Integer, nil]
    # @param automatically_unpin_topics             [Boolean, nil]
    # @param bookmark_auto_delete_preference        [Integer, nil]
    # @param chat_email_frequency                   [Integer, nil]
    # @param chat_enabled                           [Boolean, nil]
    # @param chat_header_indicator_preference       [Integer, nil]
    # @param chat_quick_reaction_type               [Integer, nil]
    # @param chat_quick_reactions_custom            [String, nil]
    # @param chat_send_shortcut                     [Integer, nil]
    # @param chat_separate_sidebar_mode             [Integer, nil]
    # @param chat_sound                             [String, nil]
    # @param color_scheme_id                        [Integer, String, nil]
    # @param composition_mode                       [Integer, nil]
    # @param dark_scheme_id                         [Integer, String, nil]
    # @param default_calendar                       [Integer, nil]
    # @param digest_after_minutes                   [Integer, nil]
    # @param dismissed_channel_retention_reminder   [Boolean, nil]
    # @param dismissed_dm_retention_reminder        [Boolean, nil]
    # @param dynamic_favicon                        [Boolean, nil]
    # @param email_digests                          [Boolean, nil]
    # @param email_in_reply_to                      [Boolean, nil]
    # @param email_level                            [Integer, nil]
    # @param email_messages_level                   [Integer, nil]
    # @param email_previous_replies                 [Integer, nil]
    # @param enable_allowed_pm_users                [Boolean, nil]
    # @param enable_defer                           [Boolean, nil]
    # @param enable_markdown_monospace_font         [Boolean, nil]
    # @param enable_quoting                         [Boolean, nil]
    # @param enable_smart_lists                     [Boolean, nil]
    # @param external_links_in_new_tab              [Boolean, nil]
    # @param hide_presence                          [Boolean, nil]
    # @param hide_profile                           [Boolean, nil]
    # @param hide_profile_and_presence              [Boolean, nil]
    # @param homepage_id                            [Integer, String, nil]
    # @param ignore_channel_wide_mention            [Boolean, nil]
    # @param include_tl0_in_digests                 [Boolean, nil]
    # @param interface_color_mode                   [Integer, nil]
    # @param last_redirected_to_top_at              [Time, nil]
    # @param like_notification_frequency            [Integer, nil]
    # @param mailing_list_mode                      [Boolean, nil]
    # @param mailing_list_mode_frequency            [Integer, nil]
    # @param new_topic_duration_minutes             [Integer, nil]
    # @param notification_level_when_assigned       [Integer, nil]
    # @param notification_level_when_replying       [Integer, nil]
    # @param oldest_search_log_date                 [Time, nil]
    # @param only_chat_push_notifications           [Boolean, nil]
    # @param policy_email_frequency                 [Integer, nil]
    # @param seen_popups                            [Integer, nil]
    # @param show_thread_title_prompts              [Boolean, nil]
    # @param sidebar_link_to_filtered_list          [Boolean, nil]
    # @param sidebar_show_count_of_new_items        [Boolean, nil]
    # @param skip_new_user_tips                     [Boolean, nil]
    # @param text_size_key                          [Integer, nil]
    # @param text_size_seq                          [Integer, nil]
    # @param theme_ids                              [Integer, nil]
    # @param theme_key_seq                          [Integer, nil]
    # @param timezone                               [String, nil]
    # @param title_count_mode_key                   [Integer, nil]
    # @param topics_unread_when_closed              [Boolean, nil]
    # @param watched_precedence_over_muted          [Boolean, nil]
    #
    # @return [void]
    def self.create(
      user_id:,
      ai_search_discoveries: nil,
      allow_private_messages: nil,
      auto_image_caption: nil,
      auto_track_topics_after_msecs: nil,
      automatically_unpin_topics: nil,
      bookmark_auto_delete_preference: nil,
      chat_email_frequency: nil,
      chat_enabled: nil,
      chat_header_indicator_preference: nil,
      chat_quick_reaction_type: nil,
      chat_quick_reactions_custom: nil,
      chat_send_shortcut: nil,
      chat_separate_sidebar_mode: nil,
      chat_sound: nil,
      color_scheme_id: nil,
      composition_mode: nil,
      dark_scheme_id: nil,
      default_calendar: nil,
      digest_after_minutes: nil,
      dismissed_channel_retention_reminder: nil,
      dismissed_dm_retention_reminder: nil,
      dynamic_favicon: nil,
      email_digests: nil,
      email_in_reply_to: nil,
      email_level: nil,
      email_messages_level: nil,
      email_previous_replies: nil,
      enable_allowed_pm_users: nil,
      enable_defer: nil,
      enable_markdown_monospace_font: nil,
      enable_quoting: nil,
      enable_smart_lists: nil,
      external_links_in_new_tab: nil,
      hide_presence: nil,
      hide_profile: nil,
      hide_profile_and_presence: nil,
      homepage_id: nil,
      ignore_channel_wide_mention: nil,
      include_tl0_in_digests: nil,
      interface_color_mode: nil,
      last_redirected_to_top_at: nil,
      like_notification_frequency: nil,
      mailing_list_mode: nil,
      mailing_list_mode_frequency: nil,
      new_topic_duration_minutes: nil,
      notification_level_when_assigned: nil,
      notification_level_when_replying: nil,
      oldest_search_log_date: nil,
      only_chat_push_notifications: nil,
      policy_email_frequency: nil,
      seen_popups: nil,
      show_thread_title_prompts: nil,
      sidebar_link_to_filtered_list: nil,
      sidebar_show_count_of_new_items: nil,
      skip_new_user_tips: nil,
      text_size_key: nil,
      text_size_seq: nil,
      theme_ids: nil,
      theme_key_seq: nil,
      timezone: nil,
      title_count_mode_key: nil,
      topics_unread_when_closed: nil,
      watched_precedence_over_muted: nil
    )
      ::Migrations::Database::IntermediateDB.insert(
        SQL,
        user_id,
        ::Migrations::Database.format_boolean(ai_search_discoveries),
        ::Migrations::Database.format_boolean(allow_private_messages),
        ::Migrations::Database.format_boolean(auto_image_caption),
        auto_track_topics_after_msecs,
        ::Migrations::Database.format_boolean(automatically_unpin_topics),
        bookmark_auto_delete_preference,
        chat_email_frequency,
        ::Migrations::Database.format_boolean(chat_enabled),
        chat_header_indicator_preference,
        chat_quick_reaction_type,
        chat_quick_reactions_custom,
        chat_send_shortcut,
        chat_separate_sidebar_mode,
        chat_sound,
        color_scheme_id,
        composition_mode,
        dark_scheme_id,
        default_calendar,
        digest_after_minutes,
        ::Migrations::Database.format_boolean(dismissed_channel_retention_reminder),
        ::Migrations::Database.format_boolean(dismissed_dm_retention_reminder),
        ::Migrations::Database.format_boolean(dynamic_favicon),
        ::Migrations::Database.format_boolean(email_digests),
        ::Migrations::Database.format_boolean(email_in_reply_to),
        email_level,
        email_messages_level,
        email_previous_replies,
        ::Migrations::Database.format_boolean(enable_allowed_pm_users),
        ::Migrations::Database.format_boolean(enable_defer),
        ::Migrations::Database.format_boolean(enable_markdown_monospace_font),
        ::Migrations::Database.format_boolean(enable_quoting),
        ::Migrations::Database.format_boolean(enable_smart_lists),
        ::Migrations::Database.format_boolean(external_links_in_new_tab),
        ::Migrations::Database.format_boolean(hide_presence),
        ::Migrations::Database.format_boolean(hide_profile),
        ::Migrations::Database.format_boolean(hide_profile_and_presence),
        homepage_id,
        ::Migrations::Database.format_boolean(ignore_channel_wide_mention),
        ::Migrations::Database.format_boolean(include_tl0_in_digests),
        interface_color_mode,
        ::Migrations::Database.format_datetime(last_redirected_to_top_at),
        like_notification_frequency,
        ::Migrations::Database.format_boolean(mailing_list_mode),
        mailing_list_mode_frequency,
        new_topic_duration_minutes,
        notification_level_when_assigned,
        notification_level_when_replying,
        ::Migrations::Database.format_datetime(oldest_search_log_date),
        ::Migrations::Database.format_boolean(only_chat_push_notifications),
        policy_email_frequency,
        seen_popups,
        ::Migrations::Database.format_boolean(show_thread_title_prompts),
        ::Migrations::Database.format_boolean(sidebar_link_to_filtered_list),
        ::Migrations::Database.format_boolean(sidebar_show_count_of_new_items),
        ::Migrations::Database.format_boolean(skip_new_user_tips),
        text_size_key,
        text_size_seq,
        theme_ids,
        theme_key_seq,
        timezone,
        title_count_mode_key,
        ::Migrations::Database.format_boolean(topics_unread_when_closed),
        ::Migrations::Database.format_boolean(watched_precedence_over_muted),
      )
    end
  end
end
