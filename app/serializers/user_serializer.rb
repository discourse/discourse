class UserSerializer < BasicUserSerializer

  def self.staff_attributes(*attrs)
    attributes(*attrs)
    attrs.each do |attr|
      define_method "include_#{attr}?" do
        scope.is_staff?
      end
    end
  end

  def self.private_attributes(*attrs)
    attributes(*attrs)
    attrs.each do |attr|
      define_method "include_#{attr}?" do
        can_edit
      end
    end
  end

  attributes :name,
             :email,
             :last_posted_at,
             :last_seen_at,
             :bio_raw,
             :bio_cooked,
             :created_at,
             :website,
             :profile_background,
             :card_background,
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
             :badge_count,
             :notification_count,
             :has_title_badges,
             :edit_history_public,
             :custom_fields,
             :user_fields

  has_one :invited_by, embed: :object, serializer: BasicUserSerializer
  has_many :custom_groups, embed: :object, serializer: BasicGroupSerializer
  has_many :featured_user_badges, embed: :ids, serializer: UserBadgeSerializer, root: :user_badges
  has_one  :card_badge, embed: :object, serializer: BadgeSerializer

  staff_attributes :number_of_deleted_posts,
                   :number_of_flagged_posts,
                   :number_of_flags_given,
                   :number_of_suspensions,
                   :number_of_warnings

  private_attributes :locale,
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
                     :notification_count,
                     :disable_jump_reply,
                     :gravatar_avatar_upload_id,
                     :custom_avatar_upload_id,
                     :has_title_badges,
                     :card_image_badge,
                     :card_image_badge_id

  ###
  ### ATTRIBUTES
  ###

  def include_email?
    object.id && object.id == scope.user.try(:id)
  end

  def card_badge
    object.user_profile.card_image_badge
  end


  def bio_raw
    object.user_profile.bio_raw
  end

  def include_bio_raw?
    bio_raw.present?
  end

  def bio_cooked
    object.user_profile.bio_processed
  end

  def website
    object.user_profile.website
  end

  def include_website?
    website.present?
  end

  def card_image_badge_id
    object.user_profile.card_image_badge.try(:id)
  end

  def include_card_image_badge_id?
    card_image_badge_id.present?
  end

  def card_image_badge
    object.user_profile.card_image_badge.try(:image)
  end

  def include_card_image_badge?
    card_image_badge.present?
  end

  def profile_background
    object.user_profile.profile_background
  end

  def include_profile_background?
    profile_background.present?
  end

  def card_background
    object.user_profile.card_background
  end

  def include_card_background?
    card_background.present?
  end

  def location
    object.user_profile.location
  end

  def include_location?
    location.present?
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

  def stats
    UserAction.stats(object.id, scope)
  end

  def can_send_private_message_to_user
    scope.can_send_private_message?(object)
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

  def include_suspend_reason?
    object.suspended?
  end

  def include_suspended_till?
    object.suspended?
  end

  ###
  ### STAFF ATTRIBUTES
  ###

  def number_of_deleted_posts
    Post.with_deleted
        .where(user_id: object.id)
        .where(user_deleted: false)
        .where.not(deleted_by_id: object.id)
        .where.not(deleted_at: nil)
        .count
  end

  def number_of_flagged_posts
    Post.with_deleted
        .where(user_id: object.id)
        .where(id: PostAction.where(post_action_type_id: PostActionType.notify_flag_type_ids)
                             .where(disagreed_at: nil)
                             .select(:post_id))
        .count
  end

  def number_of_flags_given
    PostAction.where(user_id: object.id)
              .where(post_action_type_id: PostActionType.notify_flag_type_ids)
              .count
  end

  def number_of_warnings
    object.warnings.count
  end

  def number_of_suspensions
    UserHistory.for(object, :suspend_user).count
  end

  ###
  ### PRIVATE ATTRIBUTES
  ###

  def auto_track_topics_after_msecs
    object.auto_track_topics_after_msecs || SiteSetting.auto_track_topics_after
  end

  def new_topic_duration_minutes
    object.new_topic_duration_minutes || SiteSetting.new_topic_duration_minutes
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

  def gravatar_avatar_upload_id
    object.user_avatar.try(:gravatar_upload_id)
  end

  def custom_avatar_upload_id
    object.user_avatar.try(:custom_upload_id)
  end

  def has_title_badges
    object.badges.where(allow_title: true).count > 0
  end

  def notification_count
    Notification.where(user_id: object.id).count
  end

  def include_edit_history_public?
    can_edit && !SiteSetting.edit_history_visible_to_public
  end

  def user_fields
    object.user_fields
  end

  def include_user_fields?
    user_fields.present?
  end

  def custom_fields
    fields = nil

    if SiteSetting.public_user_custom_fields.present?
      fields = SiteSetting.public_user_custom_fields.split('|')
    end

    if fields.present?
      User.custom_fields_for_ids([object.id], fields)[object.id]
    else
      {}
    end
  end
end
