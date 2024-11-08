# frozen_string_literal: true

class UserUpdater
  CATEGORY_IDS = {
    watched_first_post_category_ids: :watching_first_post,
    watched_category_ids: :watching,
    tracked_category_ids: :tracking,
    regular_category_ids: :regular,
    muted_category_ids: :muted,
  }.freeze

  TAG_NAMES = {
    watching_first_post_tags: :watching_first_post,
    watched_tags: :watching,
    tracked_tags: :tracking,
    muted_tags: :muted,
  }.freeze

  # rubocop:disable Style/MutableConstant
  OPTION_ATTR = %i[
    mailing_list_mode
    mailing_list_mode_frequency
    email_digests
    email_level
    email_messages_level
    external_links_in_new_tab
    enable_quoting
    enable_smart_lists
    enable_defer
    color_scheme_id
    dark_scheme_id
    dynamic_favicon
    automatically_unpin_topics
    digest_after_minutes
    new_topic_duration_minutes
    auto_track_topics_after_msecs
    notification_level_when_replying
    email_previous_replies
    email_in_reply_to
    like_notification_frequency
    include_tl0_in_digests
    theme_ids
    allow_private_messages
    enable_allowed_pm_users
    homepage_id
    hide_profile
    hide_presence
    text_size
    title_count_mode
    timezone
    skip_new_user_tips
    seen_popups
    default_calendar
    bookmark_auto_delete_preference
    sidebar_link_to_filtered_list
    sidebar_show_count_of_new_items
    watched_precedence_over_muted
    topics_unread_when_closed
  ]
  # rubocop:enable Style/MutableConstant

  NOTIFICATION_SCHEDULE_ATTRS = -> do
    attrs = [:enabled]
    7.times do |n|
      attrs.push("day_#{n}_start_time".to_sym)
      attrs.push("day_#{n}_end_time".to_sym)
    end
    { user_notification_schedule: attrs }
  end.call

  def initialize(actor, user)
    @user = user
    @user_guardian = Guardian.new(user)
    @guardian = Guardian.new(actor)
    @actor = actor
  end

  def update(attributes = {})
    user_profile = user.user_profile
    user_profile.dismissed_banner_key = attributes[:dismissed_banner_key] if attributes[
      :dismissed_banner_key
    ].present?
    unless SiteSetting.enable_discourse_connect && SiteSetting.discourse_connect_overrides_bio
      user_profile.bio_raw = attributes.fetch(:bio_raw) { user_profile.bio_raw }
    end

    unless SiteSetting.enable_discourse_connect && SiteSetting.discourse_connect_overrides_location
      user_profile.location = attributes.fetch(:location) { user_profile.location }
    end

    unless SiteSetting.enable_discourse_connect && SiteSetting.discourse_connect_overrides_website
      user_profile.website = format_url(attributes.fetch(:website) { user_profile.website })
    end

    if attributes[:profile_background_upload_url] == "" ||
         !guardian.can_upload_profile_header?(user)
      user_profile.profile_background_upload_id = nil
    elsif upload = Upload.get_from_url(attributes[:profile_background_upload_url])
      user_profile.profile_background_upload_id = upload.id
    end

    if attributes[:card_background_upload_url] == "" ||
         !guardian.can_upload_user_card_background?(user)
      user_profile.card_background_upload_id = nil
    elsif upload = Upload.get_from_url(attributes[:card_background_upload_url])
      user_profile.card_background_upload_id = upload.id
    end

    if attributes[:user_notification_schedule]
      user_notification_schedule =
        user.user_notification_schedule || UserNotificationSchedule.new(user: user)
      user_notification_schedule.assign_attributes(attributes[:user_notification_schedule])
    end

    old_user_name = user.name.present? ? user.name : ""

    user.name = attributes.fetch(:name) { user.name } if guardian.can_edit_name?(user)

    user.locale = attributes.fetch(:locale) { user.locale }
    user.date_of_birth = attributes.fetch(:date_of_birth) { user.date_of_birth }

    if attributes[:title] && attributes[:title] != user.title &&
         guardian.can_grant_title?(user, attributes[:title])
      user.title = attributes[:title]
    end

    if SiteSetting.user_selected_primary_groups && attributes[:primary_group_id] &&
         attributes[:primary_group_id] != user.primary_group_id &&
         guardian.can_use_primary_group?(user, attributes[:primary_group_id])
      user.primary_group_id = attributes[:primary_group_id]
    elsif SiteSetting.user_selected_primary_groups && attributes[:primary_group_id] &&
          attributes[:primary_group_id].blank?
      user.primary_group_id = nil
    end

    attributes[:homepage_id] = nil if attributes[:homepage_id] == "-1"

    if attributes[:flair_group_id] && attributes[:flair_group_id] != user.flair_group_id &&
         (
           attributes[:flair_group_id].blank? ||
             guardian.can_use_flair_group?(user, attributes[:flair_group_id])
         )
      user.flair_group_id = attributes[:flair_group_id]
    end

    if @guardian.can_change_tracking_preferences?(user)
      CATEGORY_IDS.each do |attribute, level|
        if ids = attributes[attribute]
          CategoryUser.batch_set(user, level, ids)
        end
      end

      TAG_NAMES.each do |attribute, level|
        if attributes.has_key?(attribute)
          TagUser.batch_set(user, level, attributes[attribute]&.split(",") || [])
        end
      end
    end

    save_options = false

    # special handling for theme_id cause we need to bump a sequence number
    if attributes.key?(:theme_ids)
      attributes[:theme_ids].reject!(&:blank?)
      attributes[:theme_ids].map!(&:to_i)

      if @user_guardian.allow_themes?(attributes[:theme_ids])
        user.user_option.theme_key_seq += 1 if user.user_option.theme_ids != attributes[:theme_ids]
      else
        attributes.delete(:theme_ids)
      end
    end

    if attributes.key?(:text_size)
      user.user_option.text_size_seq += 1 if user.user_option.text_size.to_s !=
        attributes[:text_size]
    end

    OPTION_ATTR.each do |attribute|
      if attributes.key?(attribute)
        save_options = true

        if [true, false].include?(user.user_option.public_send(attribute))
          val = attributes[attribute].to_s == "true"
          user.user_option.public_send("#{attribute}=", val)
        else
          user.user_option.public_send("#{attribute}=", attributes[attribute])
        end
      end
    end

    if attributes.key?(:skip_new_user_tips) && user.user_option.skip_new_user_tips
      user.user_option.seen_popups = [-1]
    end

    # automatically disable digests when mailing_list_mode is enabled
    user.user_option.email_digests = false if user.user_option.mailing_list_mode

    fields = attributes[:custom_fields]
    user.custom_fields = user.custom_fields.merge(fields) if fields.present?

    saved = nil

    User.transaction do
      update_muted_users(attributes[:muted_usernames]) if attributes.key?(:muted_usernames)

      if attributes.key?(:allowed_pm_usernames)
        update_allowed_pm_users(attributes[:allowed_pm_usernames])
      end

      if attributes.key?(:discourse_connect)
        update_discourse_connect(attributes[:discourse_connect])
      end

      if attributes.key?(:user_associated_accounts)
        updated_associated_accounts(attributes[:user_associated_accounts])
      end

      if attributes.key?(:sidebar_category_ids)
        SidebarSectionLinksUpdater.update_category_section_links(
          user,
          category_ids:
            Category
              .secured(@user_guardian)
              .where(id: attributes[:sidebar_category_ids])
              .pluck(:id),
        )
      end

      if attributes.key?(:sidebar_tag_names) && SiteSetting.tagging_enabled
        SidebarSectionLinksUpdater.update_tag_section_links(
          user,
          tag_ids:
            DiscourseTagging
              .filter_visible(Tag, @user_guardian)
              .where(name: attributes[:sidebar_tag_names])
              .pluck(:id),
        )
      end

      if SiteSetting.enable_user_status?
        update_user_status(attributes[:status]) if attributes.has_key?(:status)
      end

      name_changed = user.name_changed?
      saved =
        (!save_options || user.user_option.save) &&
          (user_notification_schedule.nil? || user_notification_schedule.save) &&
          user_profile.save && user.save

      if saved && (name_changed && old_user_name.casecmp(attributes.fetch(:name)) != 0)
        StaffActionLogger.new(@actor).log_name_change(
          user.id,
          old_user_name,
          attributes.fetch(:name) { "" },
        )
      end
      DiscourseEvent.trigger(:within_user_updater_transaction, user, attributes)
    rescue Addressable::URI::InvalidURIError => e
      # Prevent 500 for crazy url input
      return saved
    end

    if saved
      if user_notification_schedule
        if user_notification_schedule.enabled
          user_notification_schedule.create_do_not_disturb_timings(delete_existing: true)
        else
          user_notification_schedule.destroy_scheduled_timings
        end
      end
      DiscourseEvent.trigger(:user_updated, user)

      if attributes[:custom_fields].present? && user.needs_required_fields_check?
        UserHistory.create!(
          action: UserHistory.actions[:filled_in_required_fields],
          acting_user_id: user.id,
        )
      end
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
      MutedUser.where("user_id = ? AND muted_user_id not in (?)", user.id, desired_ids).destroy_all

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
      AllowedPmUser.where(
        "user_id = ? AND allowed_pm_user_id not in (?)",
        user.id,
        desired_ids,
      ).destroy_all

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

  def updated_associated_accounts(associations)
    associations.each do |association|
      user_associated_account =
        UserAssociatedAccount.find_or_initialize_by(
          user_id: user.id,
          provider_name: association[:provider_name],
        )
      if association[:provider_uid].present?
        user_associated_account.update!(provider_uid: association[:provider_uid])
      else
        user_associated_account.destroy!
      end
    end
  end

  private

  def update_user_status(status)
    if status.blank?
      @user.clear_status!
    else
      @user.set_status!(status[:description], status[:emoji], status[:ends_at])
    end
  end

  def update_discourse_connect(discourse_connect)
    external_id = discourse_connect[:external_id]
    sso = SingleSignOnRecord.find_or_initialize_by(user_id: user.id)

    if external_id.present?
      sso.update!(
        external_id: discourse_connect[:external_id],
        last_payload: "external_id=#{discourse_connect[:external_id]}",
      )
    else
      sso.destroy!
    end
  end

  attr_reader :user, :guardian

  def format_url(website)
    return nil if website.blank?
    website =~ /\Ahttp/ ? website : "http://#{website}"
  end
end
