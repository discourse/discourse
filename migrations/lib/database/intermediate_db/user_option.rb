# frozen_string_literal: true

# This file is auto-generated from the IntermediateDB schema. To make changes,
# update the configuration files in "migrations/config/schema/" and then run
# `migrations/bin/cli schema generate` to regenerate this file.

module Migrations::Database::IntermediateDB
  module UserOption
    SQL = <<~SQL
      INSERT INTO user_options (
        user_id,
        allow_private_messages,
        auto_track_topics_after_msecs,
        automatically_unpin_topics,
        bookmark_auto_delete_preference,
        color_scheme_id,
        composition_mode,
        dark_scheme_id,
        default_calendar,
        digest_after_minutes,
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
        include_tl0_in_digests,
        interface_color_mode,
        last_redirected_to_top_at,
        like_notification_frequency,
        mailing_list_mode,
        mailing_list_mode_frequency,
        new_topic_duration_minutes,
        notification_level_when_replying,
        notify_on_linked_posts,
        oldest_search_log_date,
        seen_popups,
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
        ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?
      )
    SQL
    private_constant :SQL

    # Creates a new `user_options` record in the IntermediateDB.
    #
    # @param user_id                            [Integer, String]
    # @param allow_private_messages             [Boolean, nil]
    # @param auto_track_topics_after_msecs      [Integer, nil]
    # @param automatically_unpin_topics         [Boolean, nil]
    # @param bookmark_auto_delete_preference    [Integer, nil]
    # @param color_scheme_id                    [Integer, String, nil]
    # @param composition_mode                   [Integer, nil]
    # @param dark_scheme_id                     [Integer, String, nil]
    # @param default_calendar                   [Integer, nil]
    # @param digest_after_minutes               [Integer, nil]
    # @param dynamic_favicon                    [Boolean, nil]
    # @param email_digests                      [Boolean, nil]
    # @param email_in_reply_to                  [Boolean, nil]
    # @param email_level                        [Integer, nil]
    # @param email_messages_level               [Integer, nil]
    # @param email_previous_replies             [Integer, nil]
    # @param enable_allowed_pm_users            [Boolean, nil]
    # @param enable_defer                       [Boolean, nil]
    # @param enable_markdown_monospace_font     [Boolean, nil]
    # @param enable_quoting                     [Boolean, nil]
    # @param enable_smart_lists                 [Boolean, nil]
    # @param external_links_in_new_tab          [Boolean, nil]
    # @param hide_presence                      [Boolean, nil]
    # @param hide_profile                       [Boolean, nil]
    # @param hide_profile_and_presence          [Boolean, nil]
    # @param homepage_id                        [Integer, String, nil]
    # @param include_tl0_in_digests             [Boolean, nil]
    # @param interface_color_mode               [Integer, nil]
    # @param last_redirected_to_top_at          [Time, nil]
    # @param like_notification_frequency        [Integer, nil]
    # @param mailing_list_mode                  [Boolean, nil]
    # @param mailing_list_mode_frequency        [Integer, nil]
    # @param new_topic_duration_minutes         [Integer, nil]
    # @param notification_level_when_replying   [Integer, nil]
    # @param notify_on_linked_posts             [Boolean, nil]
    # @param oldest_search_log_date             [Time, nil]
    # @param seen_popups                        [Integer, nil]
    # @param sidebar_link_to_filtered_list      [Boolean, nil]
    # @param sidebar_show_count_of_new_items    [Boolean, nil]
    # @param skip_new_user_tips                 [Boolean, nil]
    # @param text_size_key                      [Integer, nil]
    # @param text_size_seq                      [Integer, nil]
    # @param theme_ids                          [Integer, nil]
    # @param theme_key_seq                      [Integer, nil]
    # @param timezone                           [String, nil]
    # @param title_count_mode_key               [Integer, nil]
    # @param topics_unread_when_closed          [Boolean, nil]
    # @param watched_precedence_over_muted      [Boolean, nil]
    #
    # @return [void]
    def self.create(
      user_id:,
      allow_private_messages: nil,
      auto_track_topics_after_msecs: nil,
      automatically_unpin_topics: nil,
      bookmark_auto_delete_preference: nil,
      color_scheme_id: nil,
      composition_mode: nil,
      dark_scheme_id: nil,
      default_calendar: nil,
      digest_after_minutes: nil,
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
      include_tl0_in_digests: nil,
      interface_color_mode: nil,
      last_redirected_to_top_at: nil,
      like_notification_frequency: nil,
      mailing_list_mode: nil,
      mailing_list_mode_frequency: nil,
      new_topic_duration_minutes: nil,
      notification_level_when_replying: nil,
      notify_on_linked_posts: nil,
      oldest_search_log_date: nil,
      seen_popups: nil,
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
      Migrations::Database::IntermediateDB.insert(
        SQL,
        user_id,
        Migrations::Database.format_boolean(allow_private_messages),
        auto_track_topics_after_msecs,
        Migrations::Database.format_boolean(automatically_unpin_topics),
        bookmark_auto_delete_preference,
        color_scheme_id,
        composition_mode,
        dark_scheme_id,
        default_calendar,
        digest_after_minutes,
        Migrations::Database.format_boolean(dynamic_favicon),
        Migrations::Database.format_boolean(email_digests),
        Migrations::Database.format_boolean(email_in_reply_to),
        email_level,
        email_messages_level,
        email_previous_replies,
        Migrations::Database.format_boolean(enable_allowed_pm_users),
        Migrations::Database.format_boolean(enable_defer),
        Migrations::Database.format_boolean(enable_markdown_monospace_font),
        Migrations::Database.format_boolean(enable_quoting),
        Migrations::Database.format_boolean(enable_smart_lists),
        Migrations::Database.format_boolean(external_links_in_new_tab),
        Migrations::Database.format_boolean(hide_presence),
        Migrations::Database.format_boolean(hide_profile),
        Migrations::Database.format_boolean(hide_profile_and_presence),
        homepage_id,
        Migrations::Database.format_boolean(include_tl0_in_digests),
        interface_color_mode,
        Migrations::Database.format_datetime(last_redirected_to_top_at),
        like_notification_frequency,
        Migrations::Database.format_boolean(mailing_list_mode),
        mailing_list_mode_frequency,
        new_topic_duration_minutes,
        notification_level_when_replying,
        Migrations::Database.format_boolean(notify_on_linked_posts),
        Migrations::Database.format_datetime(oldest_search_log_date),
        seen_popups,
        Migrations::Database.format_boolean(sidebar_link_to_filtered_list),
        Migrations::Database.format_boolean(sidebar_show_count_of_new_items),
        Migrations::Database.format_boolean(skip_new_user_tips),
        text_size_key,
        text_size_seq,
        theme_ids,
        theme_key_seq,
        timezone,
        title_count_mode_key,
        Migrations::Database.format_boolean(topics_unread_when_closed),
        Migrations::Database.format_boolean(watched_precedence_over_muted),
      )
    end
  end
end
