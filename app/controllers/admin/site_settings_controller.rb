# frozen_string_literal: true

class Admin::SiteSettingsController < Admin::AdminController
  rescue_from Discourse::InvalidParameters do |e|
    render_json_error e.message, status: 422
  end

  def index
    render_json_dump(site_settings: SiteSetting.all_settings, diags: SiteSetting.diags)
  end

  def update
    params.require(:id)
    id = params[:id]
    value = params[id]
    value.strip! if value.is_a?(String)
    raise_access_hidden_setting(id)

    if SiteSetting.type_supervisor.get_type(id) == :upload
      value = Upload.find_by(url: value) || ''
    end

    update_existing_users = params[:updateExistingUsers].present?
    previous_value = SiteSetting.send(id) || "" if update_existing_users

    SiteSetting.set_and_log(id, value, current_user)

    if update_existing_users
      new_value = value || ""

      if (user_option = user_options[id.to_sym]).present?
        if user_option == "text_size_key"
          previous_value = UserOption.text_sizes[previous_value.to_sym]
          new_value = UserOption.text_sizes[new_value.to_sym]
        elsif user_option == "title_count_mode_key"
          previous_value = UserOption.title_count_modes[previous_value.to_sym]
          new_value = UserOption.title_count_modes[new_value.to_sym]
        end

        UserOption.where(user_option => previous_value).update_all(user_option => new_value)

        if id == "default_email_digest_frequency"
          disable_digests = new_value == 0
          UserOption.where(user_option => 0, email_digests: !disable_digests).update_all(email_digests: disable_digests)
        end
      elsif id.start_with?("default_categories_")
        previous_category_ids = previous_value.split("|")
        new_category_ids = new_value.split("|")

        case id
        when "default_categories_watching"
          notification_level = NotificationLevels.all[:watching]
        when "default_categories_tracking"
          notification_level = NotificationLevels.all[:tracking]
        when "default_categories_muted"
          notification_level = NotificationLevels.all[:muted]
        when "default_categories_watching_first_post"
          notification_level = NotificationLevels.all[:watching_first_post]
        end

        CategoryUser.where(category_id: (previous_category_ids - new_category_ids), notification_level: notification_level).delete_all

        (new_category_ids - previous_category_ids).each do |category_id|
          skip_user_ids = CategoryUser.where(category_id: category_id).pluck(:user_id)

          User.where.not(id: skip_user_ids).select(:id).find_in_batches do |users|
            category_users = []
            users.each { |user| category_users << { category_id: category_id, user_id: user.id, notification_level: notification_level } }
            CategoryUser.insert_all!(category_users)
          end
        end
      elsif id.start_with?("default_tags_")
        previous_tag_ids = Tag.where(name: previous_value.split("|")).pluck(:id)
        new_tag_ids = Tag.where(name: new_value.split("|")).pluck(:id)
        now = Time.zone.now

        case id
        when "default_tags_watching"
          notification_level = NotificationLevels.all[:watching]
        when "default_tags_tracking"
          notification_level = NotificationLevels.all[:tracking]
        when "default_tags_muted"
          notification_level = NotificationLevels.all[:muted]
        when "default_tags_watching_first_post"
          notification_level = NotificationLevels.all[:watching_first_post]
        end

        TagUser.where(tag_id: (previous_tag_ids - new_tag_ids), notification_level: notification_level).delete_all

        (new_tag_ids - previous_tag_ids).each do |tag_id|
          skip_user_ids = TagUser.where(tag_id: tag_id).pluck(:user_id)

          User.where.not(id: skip_user_ids).select(:id).find_in_batches do |users|
            tag_users = []
            users.each { |user| tag_users << { tag_id: tag_id, user_id: user.id, notification_level: notification_level, created_at: now, updated_at: now } }
            TagUser.insert_all!(tag_users)
          end
        end
      end
    end

    render body: nil
  end

  def user_count
    params.require(:site_setting_id)
    id = params[:site_setting_id]
    raise Discourse::NotFound unless id.start_with?("default_")
    new_value = params[id] || ""

    raise_access_hidden_setting(id)
    previous_value = SiteSetting.send(id) || ""
    json = {}

    if (user_option = user_options[id.to_sym]).present?
      if user_option == "text_size_key"
        previous_value = UserOption.text_sizes[previous_value.to_sym]
      elsif user_option == "title_count_mode_key"
        previous_value = UserOption.title_count_modes[previous_value.to_sym]
      end

      json[:user_count] = UserOption.where(user_option => previous_value).count
    elsif id.start_with?("default_categories_")
      previous_category_ids = previous_value.split("|")
      new_category_ids = new_value.split("|")

      case id
      when "default_categories_watching"
        notification_level = NotificationLevels.all[:watching]
      when "default_categories_tracking"
        notification_level = NotificationLevels.all[:tracking]
      when "default_categories_muted"
        notification_level = NotificationLevels.all[:muted]
      when "default_categories_watching_first_post"
        notification_level = NotificationLevels.all[:watching_first_post]
      end

      user_ids = CategoryUser.where(category_id: previous_category_ids - new_category_ids, notification_level: notification_level).distinct.pluck(:user_id)
      user_ids += User
        .joins("CROSS JOIN categories c")
        .joins("LEFT JOIN category_users cu ON users.id = cu.user_id AND c.id = cu.category_id")
        .where("c.id IN (?) AND cu.notification_level IS NULL", new_category_ids - previous_category_ids)
        .distinct
        .pluck("users.id")

      json[:user_count] = user_ids.uniq.count
    elsif id.start_with?("default_tags_")
      previous_tag_ids = Tag.where(name: previous_value.split("|")).pluck(:id)
      new_tag_ids = Tag.where(name: new_value.split("|")).pluck(:id)

      case id
      when "default_tags_watching"
        notification_level = TagUser.notification_levels[:watching]
      when "default_tags_tracking"
        notification_level = TagUser.notification_levels[:tracking]
      when "default_tags_muted"
        notification_level = TagUser.notification_levels[:muted]
      when "default_tags_watching_first_post"
        notification_level = TagUser.notification_levels[:watching_first_post]
      end

      user_ids = TagUser.where(tag_id: previous_tag_ids - new_tag_ids, notification_level: notification_level).distinct.pluck(:user_id)
      user_ids += User
        .joins("CROSS JOIN tags t")
        .joins("LEFT JOIN tag_users tu ON users.id = tu.user_id AND t.id = tu.tag_id")
        .where("t.id IN (?) AND tu.notification_level IS NULL", new_tag_ids - previous_tag_ids)
        .distinct
        .pluck("users.id")

      json[:user_count] = user_ids.uniq.count
    end

    render json: json
  end

  private

  def user_options
    {
      default_email_mailing_list_mode: "mailing_list_mode",
      default_email_mailing_list_mode_frequency: "mailing_list_mode_frequency",
      default_email_level: "email_level",
      default_email_messages_level: "email_messages_level",
      default_topics_automatic_unpin: "automatically_unpin_topics",
      default_email_previous_replies: "email_previous_replies",
      default_email_in_reply_to: "email_in_reply_to",
      default_other_enable_quoting: "enable_quoting",
      default_other_enable_defer: "enable_defer",
      default_other_external_links_in_new_tab: "external_links_in_new_tab",
      default_other_dynamic_favicon: "dynamic_favicon",
      default_other_new_topic_duration_minutes: "new_topic_duration_minutes",
      default_other_auto_track_topics_after_msecs: "auto_track_topics_after_msecs",
      default_other_notification_level_when_replying: "notification_level_when_replying",
      default_other_like_notification_frequency: "like_notification_frequency",
      default_email_digest_frequency: "digest_after_minutes",
      default_include_tl0_in_digests: "include_tl0_in_digests",
      default_text_size: "text_size_key",
      default_title_count_mode: "title_count_mode_key"
    }
  end

  def raise_access_hidden_setting(id)
    # note, as of Ruby 2.3 symbols are GC'd so this is considered safe
    if SiteSetting.hidden_settings.include?(id.to_sym)
      raise Discourse::InvalidParameters, "You are not allowed to change hidden settings"
    end
  end

end
