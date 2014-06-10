class UserSerializer < BasicUserSerializer

  attributes :name,
             :email,
             :last_posted_at,
             :last_seen_at,
             :bio_raw,
             :bio_cooked,
             :created_at,
             :website,
             :profile_background,
             :location,
             :can_edit,
             :can_edit_username,
             :can_edit_email,
             :can_edit_name,
             :stats,
             :can_send_private_message_to_user,
             :bio_excerpt,
             :trust_level,
             :moderator,
             :admin,
             :title,
             :suspend_reason,
             :suspended_till,
             :uploaded_avatar_id,
             :badge_count

  has_one :invited_by, embed: :object, serializer: BasicUserSerializer
  has_many :custom_groups, embed: :object, serializer: BasicGroupSerializer
  has_many :featured_user_badges, embed: :ids, serializer: UserBadgeSerializer, root: :user_badges

  def self.private_attributes(*attrs)
    attributes(*attrs)
    attrs.each do |attr|
      define_method "include_#{attr}?" do
        can_edit
      end
    end
  end

  def bio_excerpt
    # If they have a bio return it
    excerpt = object.user_profile.bio_excerpt
    return excerpt if excerpt.present?

    # Without a bio, determine what message to show
    if scope.user && scope.user.id == object.id
      I18n.t('user_profile.no_info_me', username_lower: object.username_lower)
    else
      I18n.t('user_profile.no_info_other', name: object.name)
    end
  end

  private_attributes :email,
                     :locale,
                     :email_digests,
                     :email_private_messages,
                     :email_direct,
                     :email_always,
                     :digest_after_days,
                     :mailing_list_mode,
                     :auto_track_topics_after_msecs,
                     :new_topic_duration_minutes,
                     :external_links_in_new_tab,
                     :dynamic_favicon,
                     :enable_quoting,
                     :muted_category_ids,
                     :tracked_category_ids,
                     :watched_category_ids,
                     :private_messages_stats,
                     :disable_jump_reply,
                     :gravatar_avatar_upload_id,
                     :custom_avatar_upload_id,
                     :custom_fields

  def gravatar_avatar_upload_id
    object.user_avatar.try(:gravatar_upload_id)
  end

  def custom_avatar_upload_id
    object.user_avatar.try(:custom_upload_id)
  end

  def auto_track_topics_after_msecs
    object.auto_track_topics_after_msecs || SiteSetting.auto_track_topics_after
  end

  def new_topic_duration_minutes
    object.new_topic_duration_minutes || SiteSetting.new_topic_duration_minutes
  end

  def can_send_private_message_to_user
    scope.can_send_private_message?(object)
  end

  def can_edit
    scope.can_edit?(object)
  end

  def can_edit_username
    scope.can_edit_username?(object)
  end

  def can_edit_email
    scope.can_edit_email?(object)
  end

  def can_edit_name
    scope.can_edit_name?(object)
  end

  def location
    object.user_profile.location
  end
  def include_location?
    location.present?
  end

  def website
    object.user_profile.website
  end
  def include_website?
    website.present?
  end

  def include_bio_raw?
    bio_raw.present?
  end
  def bio_raw
    object.user_profile.bio_raw
  end

  def bio_cooked
    object.user_profile.bio_processed
  end

  def stats
    UserAction.stats(object.id, scope)
  end

  def include_suspended?
    object.suspended?
  end
  def include_suspend_reason?
    object.suspended?
  end

  def include_suspended_till?
    object.suspended?
  end

  def muted_category_ids
    CategoryUser.lookup(object, :muted).pluck(:category_id)
  end

  def tracked_category_ids
    CategoryUser.lookup(object, :tracking).pluck(:category_id)
  end

  def watched_category_ids
    CategoryUser.lookup(object, :watching).pluck(:category_id)
  end

  def private_messages_stats
    UserAction.private_messages_stats(object.id, scope)
  end
end
