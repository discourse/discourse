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
      Jobs.enqueue(
        :site_setting_update_default_categories,
        { id: id, value: value, previous_value: previous_value },
      )
      MessageBus.publish(
        "/site_setting/#{id}/process",
        status: "enqueued",
        group_ids: [Group::AUTO_GROUPS[:admins]],
      )
    elsif id.start_with?("default_tags_")
      Jobs.enqueue(
        :site_setting_update_default_tags,
        { id: id, value: value, previous_value: previous_value },
      )
      MessageBus.publish(
        "/site_setting/#{id}/process",
        status: "enqueued",
        group_ids: [Group::AUTO_GROUPS[:admins]],
      )
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
      default_other_enable_markdown_monospace_font: "enable_markdown_monospace_font",
      default_email_digest_frequency: "digest_after_minutes",
      default_include_tl0_in_digests: "include_tl0_in_digests",
      default_text_size: "text_size_key",
      default_title_count_mode: "title_count_mode_key",
      default_hide_profile: "hide_profile",
      default_hide_presence: "hide_presence",
      default_sidebar_link_to_filtered_list: "sidebar_link_to_filtered_list",
      default_sidebar_show_count_of_new_items: "sidebar_show_count_of_new_items",
      default_composition_mode: "composition_mode",
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

  def self.default_categories(id, value, previous_value)
    new_value = value.nil? ? "" : value

    batch_size = 50_000
    previous_category_ids = previous_value.split("|")
    new_category_ids = new_value.split("|")

    notification_level = category_notification_level(id)

    categories_to_unwatch = previous_category_ids - new_category_ids

    CategoryUser
      .where(category_id: categories_to_unwatch, notification_level: notification_level)
      .in_batches(of: batch_size) { |batch| batch.delete_all }

    TopicUser
      .joins(:topic)
      .where(
        notification_level: TopicUser.notification_levels[:watching],
        notifications_reason_id: TopicUser.notification_reasons[:auto_watch_category],
        topics: {
          category_id: categories_to_unwatch,
        },
      )
      .select("topic_users.id")
      .in_batches(of: batch_size) do |batch|
        batch.update_all(notification_level: TopicUser.notification_levels[:regular])
      end

    modified_categories = new_category_ids - previous_category_ids

    skip_user_ids = {}
    users_scope = {}

    modified_categories.each do |category_id|
      skip_user_ids[category_id] = CategoryUser.where(category_id: category_id).pluck(:user_id)
      users_scope[category_id] = User
        .real
        .where(staged: false)
        .where.not(id: skip_user_ids[category_id])
    end

    total_users_to_process = users_scope.values.map(&:count).sum
    processed_total = 0

    modified_categories.each do |category_id|
      users_scope[category_id]
        .select(:id)
        .find_in_batches(batch_size: batch_size) do |users|
          category_users =
            users.map do |user|
              { category_id: category_id, user_id: user.id, notification_level: notification_level }
            end

          CategoryUser.insert_all!(category_users)

          processed_total += users.size
          publish_progress(id, processed_total, total_users_to_process, modified_categories)
        end
    end

    publish_progress(id, processed_total, total_users_to_process, modified_categories)
  end

  def self.default_tags(id, value, previous_value)
    new_value = value.nil? ? "" : value

    batch_size = 50_000

    previous_tag_ids = Tag.where(name: previous_value.split("|")).pluck(:id)
    new_tag_ids = Tag.where(name: new_value.split("|")).pluck(:id)
    now = Time.zone.now

    notification_level = tag_notification_level(id)

    TagUser
      .where(tag_id: (previous_tag_ids - new_tag_ids), notification_level: notification_level)
      .in_batches(of: batch_size) { |batch| batch.delete_all }

    modified_tags = new_tag_ids - previous_tag_ids

    skip_user_ids = {}
    users_scope = {}

    modified_tags.each do |tag_id|
      skip_user_ids[:tag_id] = TagUser.where(tag_id: tag_id).pluck(:user_id)
      users_scope[:tag_id] = User.real.where(staged: false).where.not(id: skip_user_ids[:tag_id])
    end

    total_users_to_process = users_scope.values.map(&:count).sum
    processed_total = 0

    modified_tags.each do |tag_id|
      skip_user_ids[:tag_id] = TagUser.where(tag_id: tag_id).pluck(:user_id)
      users_scope[:tag_id] = User.real.where(staged: false).where.not(id: skip_user_ids[:tag_id])

      users_scope[:tag_id]
        .select(:id)
        .find_in_batches(batch_size: batch_size) do |users|
          tag_users =
            users.map do |user|
              {
                tag_id: tag_id,
                user_id: user.id,
                notification_level: notification_level,
                created_at: now,
                updated_at: now,
              }
            end

          TagUser.insert_all!(tag_users)

          processed_total += users.size
          publish_progress(id, processed_total, total_users_to_process, modified_tags)
        end
    end

    publish_progress(id, processed_total, total_users_to_process, modified_tags)
  end

  def self.publish_progress(
    site_setting_name,
    processed_total = 0,
    total_users_to_process = 0,
    modified = nil
  )
    status =
      if modified.empty? || processed_total >= total_users_to_process
        "completed"
      else
        "enqueued"
      end

    progress = modified.empty? ? nil : "#{processed_total}/#{total_users_to_process}"
    MessageBus.publish(
      "/site_setting/#{site_setting_name}/process",
      status: status,
      progress: progress,
      group_ids: [Group::AUTO_GROUPS[:admins]],
    )
  end
end
