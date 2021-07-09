# frozen_string_literal: true

class UserUpdater

  CATEGORY_IDS = {
    watched_first_post_category_ids: :watching_first_post,
    watched_category_ids: :watching,
    tracked_category_ids: :tracking,
    regular_category_ids: :regular,
    muted_category_ids: :muted
  }

  TAG_NAMES = {
    watching_first_post_tags: :watching_first_post,
    watched_tags: :watching,
    tracked_tags: :tracking,
    muted_tags: :muted
  }

  OPTION_ATTR = [
    :mailing_list_mode,
    :mailing_list_mode_frequency,
    :email_digests,
    :email_level,
    :email_messages_level,
    :external_links_in_new_tab,
    :enable_quoting,
    :enable_defer,
    :color_scheme_id,
    :dark_scheme_id,
    :dynamic_favicon,
    :automatically_unpin_topics,
    :digest_after_minutes,
    :new_topic_duration_minutes,
    :auto_track_topics_after_msecs,
    :notification_level_when_replying,
    :email_previous_replies,
    :email_in_reply_to,
    :like_notification_frequency,
    :include_tl0_in_digests,
    :theme_ids,
    :allow_private_messages,
    :enable_allowed_pm_users,
    :homepage_id,
    :hide_profile_and_presence,
    :text_size,
    :title_count_mode,
    :timezone,
    :skip_new_user_tips
  ]

  NOTIFICATION_SCHEDULE_ATTRS = -> {
    attrs = [:enabled]
    7.times do |n|
      attrs.push("day_#{n}_start_time".to_sym)
      attrs.push("day_#{n}_end_time".to_sym)
    end
    { user_notification_schedule: attrs }
  }.call

  def initialize(actor, user)
    @user = user
    @guardian = Guardian.new(actor)
    @actor = actor
  end

  def update(attributes = {})
    user_profile = user.user_profile
    user_profile.dismissed_banner_key = attributes[:dismissed_banner_key] if attributes[:dismissed_banner_key].present?
    unless SiteSetting.enable_discourse_connect && SiteSetting.discourse_connect_overrides_bio
      user_profile.bio_raw = attributes.fetch(:bio_raw) { user_profile.bio_raw }
    end

    unless SiteSetting.enable_discourse_connect && SiteSetting.discourse_connect_overrides_location
      user_profile.location = attributes.fetch(:location) { user_profile.location }
    end

    unless SiteSetting.enable_discourse_connect && SiteSetting.discourse_connect_overrides_website
      user_profile.website = format_url(attributes.fetch(:website) { user_profile.website })
    end

    if attributes[:profile_background_upload_url] == "" || !guardian.can_upload_profile_header?(user)
      user_profile.profile_background_upload_id = nil
    elsif upload = Upload.get_from_url(attributes[:profile_background_upload_url])
      user_profile.profile_background_upload_id = upload.id
    end

    if attributes[:card_background_upload_url] == "" || !guardian.can_upload_user_card_background?(user)
      user_profile.card_background_upload_id = nil
    elsif upload = Upload.get_from_url(attributes[:card_background_upload_url])
      user_profile.card_background_upload_id = upload.id
    end

    if attributes[:user_notification_schedule]
      user_notification_schedule = user.user_notification_schedule || UserNotificationSchedule.new(user: user)
      user_notification_schedule.assign_attributes(attributes[:user_notification_schedule])
    end

    old_user_name = user.name.present? ? user.name : ""
    user.name = attributes.fetch(:name) { user.name }

    user.locale = attributes.fetch(:locale) { user.locale }
    user.date_of_birth = attributes.fetch(:date_of_birth) { user.date_of_birth }

    if attributes[:title] &&
      attributes[:title] != user.title &&
      guardian.can_grant_title?(user, attributes[:title])
      user.title = attributes[:title]
    end

    if SiteSetting.user_selected_primary_groups &&
      attributes[:primary_group_id] &&
      attributes[:primary_group_id] != user.primary_group_id &&
      guardian.can_use_primary_group?(user, attributes[:primary_group_id])

      user.primary_group_id = attributes[:primary_group_id]
    elsif SiteSetting.user_selected_primary_groups &&
      attributes[:primary_group_id] &&
      attributes[:primary_group_id].blank?

      user.primary_group_id = nil
    end

    if attributes[:flair_group_id] &&
      attributes[:flair_group_id] != user.flair_group_id &&
      (attributes[:flair_group_id].blank? ||
        guardian.can_use_primary_group?(user, attributes[:flair_group_id]))

      user.flair_group_id = attributes[:flair_group_id]
    end

    CATEGORY_IDS.each do |attribute, level|
      if ids = attributes[attribute]
        CategoryUser.batch_set(user, level, ids)
      end
    end

    TAG_NAMES.each do |attribute, level|
      if attributes.has_key?(attribute)
        TagUser.batch_set(user, level, attributes[attribute]&.split(',') || [])
      end
    end

    save_options = false

    # special handling for theme_id cause we need to bump a sequence number
    if attributes.key?(:theme_ids)
      user_guardian = Guardian.new(user)
      attributes[:theme_ids].reject!(&:blank?)
      attributes[:theme_ids].map!(&:to_i)
      if user_guardian.allow_themes?(attributes[:theme_ids])
        user.user_option.theme_key_seq += 1 if user.user_option.theme_ids != attributes[:theme_ids]
      else
        attributes.delete(:theme_ids)
      end
    end

    if attributes.key?(:text_size)
      user.user_option.text_size_seq += 1 if user.user_option.text_size.to_s != attributes[:text_size]
    end

    OPTION_ATTR.each do |attribute|
      if attributes.key?(attribute)
        save_options = true

        if [true, false].include?(user.user_option.public_send(attribute))
          val = attributes[attribute].to_s == 'true'
          user.user_option.public_send("#{attribute}=", val)
        else
          user.user_option.public_send("#{attribute}=", attributes[attribute])
        end
      end
    end

    # automatically disable digests when mailing_list_mode is enabled
    user.user_option.email_digests = false if user.user_option.mailing_list_mode

    fields = attributes[:custom_fields]
    if fields.present?
      user.custom_fields = user.custom_fields.merge(fields)
    end

    saved = nil

    User.transaction do
      if attributes.key?(:muted_usernames)
        update_muted_users(attributes[:muted_usernames])
      end

      if attributes.key?(:allowed_pm_usernames)
        update_allowed_pm_users(attributes[:allowed_pm_usernames])
      end

      name_changed = user.name_changed?
      if (saved = (!save_options || user.user_option.save) && (user_notification_schedule.nil? || user_notification_schedule.save) && user_profile.save && user.save) &&
         (name_changed && old_user_name.casecmp(attributes.fetch(:name)) != 0)

        StaffActionLogger.new(@actor).log_name_change(
          user.id,
          old_user_name,
          attributes.fetch(:name) { '' }
        )
      end
    rescue Addressable::URI::InvalidURIError => e
      # Prevent 500 for crazy url input
      return saved
    end

    if saved
      if user_notification_schedule
        user_notification_schedule.enabled ?
          user_notification_schedule.create_do_not_disturb_timings(delete_existing: true) :
          user_notification_schedule.destroy_scheduled_timings
      end
      DiscourseEvent.trigger(:user_updated, user)
    end

    saved
  end

  def update_muted_users(usernames)
    usernames ||= ""
    desired_usernames = usernames.split(",").reject { |username| user.username == username }
    desired_ids = User.where(username: desired_usernames).pluck(:id)
    if desired_ids.empty?
      MutedUser.where(user_id: user.id).destroy_all
    else
      MutedUser.where('user_id = ? AND muted_user_id not in (?)', user.id, desired_ids).destroy_all

      # SQL is easier here than figuring out how to do the same in AR
      DB.exec(<<~SQL, now: Time.now, user_id: user.id, desired_ids: desired_ids)
        INSERT into muted_users(user_id, muted_user_id, created_at, updated_at)
        SELECT :user_id, id, :now, :now
        FROM users
        WHERE id in (:desired_ids)
        ON CONFLICT DO NOTHING
      SQL
    end
  end

  def update_allowed_pm_users(usernames)
    usernames ||= ""
    desired_usernames = usernames.split(",").reject { |username| user.username == username }
    desired_ids = User.where(username: desired_usernames).pluck(:id)

    if desired_ids.empty?
      AllowedPmUser.where(user_id: user.id).destroy_all
    else
      AllowedPmUser.where('user_id = ? AND allowed_pm_user_id not in (?)', user.id, desired_ids).destroy_all

      # SQL is easier here than figuring out how to do the same in AR
      DB.exec(<<~SQL, now: Time.zone.now, user_id: user.id, desired_ids: desired_ids)
        INSERT into allowed_pm_users(user_id, allowed_pm_user_id, created_at, updated_at)
        SELECT :user_id, id, :now, :now
        FROM users
        WHERE id in (:desired_ids)
        ON CONFLICT DO NOTHING
      SQL
    end
  end

  private

  attr_reader :user, :guardian

  def format_url(website)
    return nil if website.blank?
    website =~ /^http/ ? website : "http://#{website}"
  end
end
