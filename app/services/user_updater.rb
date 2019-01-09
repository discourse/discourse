class UserUpdater

  CATEGORY_IDS = {
    watched_first_post_category_ids: :watching_first_post,
    watched_category_ids: :watching,
    tracked_category_ids: :tracking,
    muted_category_ids: :muted
  }

  TAG_NAMES = {
    watching_first_post_tags: :watching_first_post,
    watched_tags: :watching,
    tracked_tags: :tracking,
    muted_tags: :muted
  }

  OPTION_ATTR = [
    :email_always,
    :mailing_list_mode,
    :mailing_list_mode_frequency,
    :email_digests,
    :email_direct,
    :email_private_messages,
    :external_links_in_new_tab,
    :enable_quoting,
    :dynamic_favicon,
    :disable_jump_reply,
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
    :homepage_id,
    :hide_profile_and_presence,
    :text_size
  ]

  def initialize(actor, user)
    @user = user
    @guardian = Guardian.new(actor)
    @actor = actor
  end

  def update(attributes = {})
    user_profile = user.user_profile
    user_profile.location = attributes.fetch(:location) { user_profile.location }
    user_profile.dismissed_banner_key = attributes[:dismissed_banner_key] if attributes[:dismissed_banner_key].present?
    user_profile.website = format_url(attributes.fetch(:website) { user_profile.website })
    unless SiteSetting.enable_sso && SiteSetting.sso_overrides_bio
      user_profile.bio_raw = attributes.fetch(:bio_raw) { user_profile.bio_raw }
    end
    user_profile.profile_background = attributes.fetch(:profile_background) { user_profile.profile_background }
    user_profile.card_background = attributes.fetch(:card_background) { user_profile.card_background }

    old_user_name = user.name.present? ? user.name : ""
    user.name = attributes.fetch(:name) { user.name }

    user.locale = attributes.fetch(:locale) { user.locale }
    user.date_of_birth = attributes.fetch(:date_of_birth) { user.date_of_birth }

    if attributes[:title] &&
      attributes[:title] != user.title &&
      guardian.can_grant_title?(user, attributes[:title])
      user.title = attributes[:title]
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

    OPTION_ATTR.each do |attribute|
      if attributes.key?(attribute)
        save_options = true

        if [true, false].include?(user.user_option.send(attribute))
          val = attributes[attribute].to_s == 'true'
          user.user_option.send("#{attribute}=", val)
        else
          user.user_option.send("#{attribute}=", attributes[attribute])
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

      name_changed = user.name_changed?
      if (saved = (!save_options || user.user_option.save) && user_profile.save && user.save) &&
         (name_changed && old_user_name.casecmp(attributes.fetch(:name)) != 0)

        StaffActionLogger.new(@actor).log_name_change(
          user.id,
          old_user_name,
          attributes.fetch(:name) { '' }
        )
      end
    end

    DiscourseEvent.trigger(:user_updated, user) if saved
    saved
  end

  def update_muted_users(usernames)
    usernames ||= ""
    desired_ids = User.where(username: usernames.split(",")).pluck(:id)
    if desired_ids.empty?
      MutedUser.where(user_id: user.id).destroy_all
    else
      MutedUser.where('user_id = ? AND muted_user_id not in (?)', user.id, desired_ids).destroy_all

      # SQL is easier here than figuring out how to do the same in AR
      DB.exec(<<~SQL, now: Time.now, user_id: user.id, desired_ids: desired_ids)
        INSERT into muted_users(user_id, muted_user_id, created_at, updated_at)
        SELECT :user_id, id, :now, :now
        FROM users
        WHERE
          id in (:desired_ids) AND
          id NOT IN (
            SELECT muted_user_id
            FROM muted_users
            WHERE user_id = :user_id
          )
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
