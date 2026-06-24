# frozen_string_literal: true

module Migrations
  module Converters
    module Discourse
      class UserOptions < Conversion::ProgressStep
        source do
          attr_accessor :source_db

          def max_progress
            @source_db.count <<~SQL
              SELECT COUNT(*)
              FROM user_options
              WHERE user_id > 0
            SQL
          end

          def items
            @source_db.query <<~SQL
              SELECT *
              FROM user_options
              WHERE user_id > 0
              ORDER BY user_id
            SQL
          end
        end

        processor do
          def process(item)
            IntermediateDB::UserOption.create(
              user_id: item[:user_id],
              allow_private_messages: item[:allow_private_messages],
              auto_track_topics_after_msecs: item[:auto_track_topics_after_msecs],
              automatically_unpin_topics: item[:automatically_unpin_topics],
              bookmark_auto_delete_preference: item[:bookmark_auto_delete_preference],
              color_scheme_id: item[:color_scheme_id],
              composition_mode: item[:composition_mode],
              dark_scheme_id: item[:dark_scheme_id],
              default_calendar: item[:default_calendar],
              digest_after_minutes: item[:digest_after_minutes],
              dynamic_favicon: item[:dynamic_favicon],
              email_digests: item[:email_digests],
              email_in_reply_to: item[:email_in_reply_to],
              email_level: item[:email_level],
              email_messages_level: item[:email_messages_level],
              email_previous_replies: item[:email_previous_replies],
              enable_allowed_pm_users: item[:enable_allowed_pm_users],
              enable_defer: item[:enable_defer],
              enable_markdown_monospace_font: item[:enable_markdown_monospace_font],
              enable_quoting: item[:enable_quoting],
              enable_smart_lists: item[:enable_smart_lists],
              enable_upcoming_change_available_notifications:
                item[:enable_upcoming_change_available_notifications],
              external_links_in_new_tab: item[:external_links_in_new_tab],
              hide_presence: item[:hide_presence],
              hide_profile: item[:hide_profile],
              hide_profile_and_presence: item[:hide_profile_and_presence],
              homepage_id: item[:homepage_id],
              include_tl0_in_digests: item[:include_tl0_in_digests],
              interface_color_mode: item[:interface_color_mode],
              last_redirected_to_top_at: item[:last_redirected_to_top_at],
              like_notification_frequency: item[:like_notification_frequency],
              mailing_list_mode: item[:mailing_list_mode],
              mailing_list_mode_frequency: item[:mailing_list_mode_frequency],
              new_topic_duration_minutes: item[:new_topic_duration_minutes],
              notification_level_when_replying: item[:notification_level_when_replying],
              notify_on_linked_posts: item[:notify_on_linked_posts],
              oldest_search_log_date: item[:oldest_search_log_date],
              seen_popups: item[:seen_popups],
              show_original_content: item[:show_original_content],
              sidebar_link_to_filtered_list: item[:sidebar_link_to_filtered_list],
              sidebar_show_count_of_new_items: item[:sidebar_show_count_of_new_items],
              skip_new_user_tips: item[:skip_new_user_tips],
              text_size_key: item[:text_size_key],
              text_size_seq: item[:text_size_seq],
              theme_ids: item[:theme_ids],
              theme_key_seq: item[:theme_key_seq],
              timezone: item[:timezone],
              title_count_mode_key: item[:title_count_mode_key],
              topics_unread_when_closed: item[:topics_unread_when_closed],
              watched_precedence_over_muted: item[:watched_precedence_over_muted],
            )
          end
        end
      end
    end
  end
end
