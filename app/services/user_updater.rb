class UserUpdater

  CATEGORY_IDS = {
    watched_category_ids: :watching,
    tracked_category_ids: :tracking,
    muted_category_ids: :muted
  }

  USER_ATTR = [
    :email_digests,
    :email_always,
    :email_direct,
    :email_private_messages,
    :external_links_in_new_tab,
    :enable_quoting,
    :dynamic_favicon,
    :mailing_list_mode,
    :disable_jump_reply,
    :edit_history_public
  ]

  def initialize(actor, user)
    @user = user
    @guardian = Guardian.new(actor)
  end

  def update(attributes = {})
    user_profile = user.user_profile
    user_profile.location = attributes[:location]
    user_profile.dismissed_banner_key = attributes[:dismissed_banner_key] if attributes[:dismissed_banner_key].present?
    user_profile.website = format_url(attributes.fetch(:website) { user_profile.website })
    user_profile.bio_raw = attributes.fetch(:bio_raw) { user_profile.bio_raw }
    user_profile.profile_background = attributes.fetch(:profile_background) { user_profile.profile_background }
    user_profile.card_background = attributes.fetch(:card_background) { user_profile.card_background }

    user.name = attributes.fetch(:name) { user.name }
    user.locale = attributes.fetch(:locale) { user.locale }
    user.digest_after_days = attributes.fetch(:digest_after_days) { user.digest_after_days }

    if attributes[:auto_track_topics_after_msecs]
      user.auto_track_topics_after_msecs = attributes[:auto_track_topics_after_msecs].to_i
    end

    if attributes[:new_topic_duration_minutes]
      user.new_topic_duration_minutes = attributes[:new_topic_duration_minutes].to_i
    end

    if guardian.can_grant_title?(user)
      user.title = attributes.fetch(:title) { user.title }
    end

    CATEGORY_IDS.each do |attribute, level|
      if ids = attributes[attribute]
        CategoryUser.batch_set(user, level, ids)
      end
    end

    USER_ATTR.each do |attribute|
      if attributes[attribute].present?
        user.send("#{attribute}=", attributes[attribute] == 'true')
      end
    end

    fields = attributes[:custom_fields]
    if fields.present?
      user.custom_fields = user.custom_fields.merge(fields)
    end

    User.transaction do
      if attributes.key?(:muted_usernames)
        update_muted_users(attributes[:muted_usernames])
      end

      user_profile.save && user.save
    end
  end

  def update_muted_users(usernames)
    usernames ||= ""
    desired_ids = User.where(username: usernames.split(",")).pluck(:id)
    if desired_ids.empty?
      MutedUser.where(user_id: user.id).destroy_all
    else
      MutedUser.where('user_id = ? AND muted_user_id not in (?)', user.id, desired_ids).destroy_all

      # SQL is easier here than figuring out how to do the same in AR
      MutedUser.exec_sql("INSERT into muted_users(user_id, muted_user_id, created_at, updated_at)
                          SELECT :user_id, id, :now, :now
                          FROM users
                          WHERE
                            id in (:desired_ids) AND
                            id NOT IN (
                              SELECT muted_user_id
                              FROM muted_users
                              WHERE user_id = :user_id
                            )",
                          now: Time.now, user_id: user.id, desired_ids: desired_ids)
    end
  end

  private

  attr_reader :user, :guardian

  def format_url(website)
    website =~ /^http/ ? website : "http://#{website}"
  end
end
