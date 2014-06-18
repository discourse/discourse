class UserUpdater

  CATEGORY_IDS = {
    watched_category_ids: :watching,
    tracked_category_ids: :tracking,
    muted_category_ids: :muted
  }

  USER_ATTR =   [
      :email_digests,
      :email_always,
      :email_direct,
      :email_private_messages,
      :external_links_in_new_tab,
      :enable_quoting,
      :dynamic_favicon,
      :mailing_list_mode,
      :disable_jump_reply
  ]

  PROFILE_ATTR = [
    :location,
    :dismissed_banner_key
  ]

  def initialize(actor, user)
    @user = user
    @guardian = Guardian.new(actor)
  end

  def update(attributes = {})
    user_profile = user.user_profile
    user_profile.website = format_url(attributes.fetch(:website) { user_profile.website })
    user_profile.bio_raw = attributes.fetch(:bio_raw) { user_profile.bio_raw }

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
        user.send("#{attribute.to_s}=", attributes[attribute] == 'true')
      end
    end

    PROFILE_ATTR.each do |attribute|
      user_profile.send("#{attribute.to_s}=", attributes[attribute])
    end

    if fields = attributes[:custom_fields]
      user.custom_fields = fields
    end

    User.transaction do
      user_profile.save
      user.save
    end
  end

  private

  attr_reader :user, :guardian

  def format_url(website)
    if website =~ /^http/
      website
    else
      "http://#{website}"
    end
  end
end
