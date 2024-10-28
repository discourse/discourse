# frozen_string_literal: true

class SiteSettingUpdateExistingUsers
  def self.call(id, value, previous_value)
    new_value = value.nil? ? "" : value

    if (user_option = self.user_options[id.to_sym]).present?
      if user_option == "text_size_key"
        previous_value = UserOption.text_sizes[previous_value.to_sym]
        new_value = UserOption.text_sizes[new_value.to_sym]
      elsif user_option == "title_count_mode_key"
        previous_value = UserOption.title_count_modes[previous_value.to_sym]
        new_value = UserOption.title_count_modes[new_value.to_sym]
      end

      attrs = { user_option => new_value }
      attrs[:email_digests] = (new_value.to_i != 0) if id == "default_email_digest_frequency"

      UserOption.human_users.where(user_option => previous_value).update_all(attrs)
    elsif id.start_with?("default_categories_")
      previous_category_ids = previous_value.split("|")
      new_category_ids = new_value.split("|")

      notification_level = self.category_notification_level(id)

      categories_to_unwatch = previous_category_ids - new_category_ids
      CategoryUser.where(
        category_id: categories_to_unwatch,
        notification_level: notification_level,
      ).delete_all
      TopicUser
        .joins(:topic)
        .where(
          notification_level: TopicUser.notification_levels[:watching],
          notifications_reason_id: TopicUser.notification_reasons[:auto_watch_category],
          topics: {
            category_id: categories_to_unwatch,
          },
        )
        .update_all(notification_level: TopicUser.notification_levels[:regular])

      (new_category_ids - previous_category_ids).each do |category_id|
        skip_user_ids = CategoryUser.where(category_id: category_id).pluck(:user_id)

        User
          .real
          .where(staged: false)
          .where.not(id: skip_user_ids)
          .select(:id)
          .find_in_batches do |users|
            category_users = []
            users.each do |user|
              category_users << {
                category_id: category_id,
                user_id: user.id,
                notification_level: notification_level,
              }
            end
            CategoryUser.insert_all!(category_users)
          end
      end
    elsif id.start_with?("default_tags_")
      previous_tag_ids = Tag.where(name: previous_value.split("|")).pluck(:id)
      new_tag_ids = Tag.where(name: new_value.split("|")).pluck(:id)
      now = Time.zone.now

      notification_level = self.tag_notification_level(id)

      TagUser.where(
        tag_id: (previous_tag_ids - new_tag_ids),
        notification_level: notification_level,
      ).delete_all

      (new_tag_ids - previous_tag_ids).each do |tag_id|
        skip_user_ids = TagUser.where(tag_id: tag_id).pluck(:user_id)

        User
          .real
          .where(staged: false)
          .where.not(id: skip_user_ids)
          .select(:id)
          .find_in_batches do |users|
            tag_users = []
            users.each do |user|
              tag_users << {
                tag_id: tag_id,
                user_id: user.id,
                notification_level: notification_level,
                created_at: now,
                updated_at: now,
              }
            end
            TagUser.insert_all!(tag_users)
          end
      end
    elsif self.is_sidebar_default_setting?(id)
      Jobs.enqueue(
        :backfill_sidebar_site_settings,
        setting_name: id,
        previous_value: previous_value,
        new_value: new_value,
      )
    end
  end

  def self.user_options
    {
      default_email_mailing_list_mode: "mailing_list_mode",
      default_email_mailing_list_mode_frequency: "mailing_list_mode_frequency",
      default_email_level: "email_level",
      default_email_messages_level: "email_messages_level",
      default_topics_automatic_unpin: "automatically_unpin_topics",
      default_email_previous_replies: "email_previous_replies",
      default_email_in_reply_to: "email_in_reply_to",
      default_other_enable_quoting: "enable_quoting",
      default_other_enable_smart_lists: "enable_smart_lists",
      default_other_enable_defer: "enable_defer",
      default_other_external_links_in_new_tab: "external_links_in_new_tab",
      default_other_dynamic_favicon: "dynamic_favicon",
      default_other_new_topic_duration_minutes: "new_topic_duration_minutes",
      default_other_auto_track_topics_after_msecs: "auto_track_topics_after_msecs",
      default_other_notification_level_when_replying: "notification_level_when_replying",
      default_other_like_notification_frequency: "like_notification_frequency",
      default_other_skip_new_user_tips: "skip_new_user_tips",
      default_email_digest_frequency: "digest_after_minutes",
      default_include_tl0_in_digests: "include_tl0_in_digests",
      default_text_size: "text_size_key",
      default_title_count_mode: "title_count_mode_key",
      default_hide_profile_and_presence: "hide_profile_and_presence",
      default_sidebar_link_to_filtered_list: "sidebar_link_to_filtered_list",
      default_sidebar_show_count_of_new_items: "sidebar_show_count_of_new_items",
    }
  end

  def self.category_notification_level(id)
    case id
    when "default_categories_watching"
      NotificationLevels.all[:watching]
    when "default_categories_tracking"
      NotificationLevels.all[:tracking]
    when "default_categories_muted"
      NotificationLevels.all[:muted]
    when "default_categories_watching_first_post"
      NotificationLevels.all[:watching_first_post]
    when "default_categories_normal"
      NotificationLevels.all[:regular]
    end
  end

  def self.tag_notification_level(id)
    case id
    when "default_tags_watching"
      NotificationLevels.all[:watching]
    when "default_tags_tracking"
      NotificationLevels.all[:tracking]
    when "default_tags_muted"
      NotificationLevels.all[:muted]
    when "default_tags_watching_first_post"
      NotificationLevels.all[:watching_first_post]
    end
  end

  def self.is_sidebar_default_setting?(setting_name)
    %w[default_navigation_menu_categories default_navigation_menu_tags].include?(setting_name.to_s)
  end
end
