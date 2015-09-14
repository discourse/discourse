class UserSerializer < BasicUserSerializer

  attr_accessor :omit_stats,
                :topic_post_count

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

  # attributes that are hidden for TL0 users when seen by anonymous
  def self.untrusted_attributes(*attrs)
    attrs.each do |attr|
      method_name = "include_#{attr}?"
      define_method(method_name) do
        return false if scope.restrict_user_fields?(object)
        send(attr).present?
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
             :website_name,
             :profile_background,
             :card_background,
             :location,
             :can_edit,
             :can_edit_username,
             :can_edit_email,
             :can_edit_name,
             :stats,
             :can_send_private_messages,
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
             :has_title_badges,
             :edit_history_public,
             :custom_fields,
             :user_fields,
             :topic_post_count,
             :pending_count

  has_one :invited_by, embed: :object, serializer: BasicUserSerializer
  has_many :custom_groups, embed: :object, serializer: BasicGroupSerializer
  has_many :featured_user_badges, embed: :ids, serializer: UserBadgeSerializer, root: :user_badges
  has_one  :card_badge, embed: :object, serializer: BadgeSerializer

  staff_attributes :post_count,
                   :can_be_deleted,
                   :can_delete_all_posts

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
                     :disable_jump_reply,
                     :system_avatar_upload_id,
                     :system_avatar_template,
                     :gravatar_avatar_upload_id,
                     :gravatar_avatar_template,
                     :custom_avatar_upload_id,
                     :custom_avatar_template,
                     :has_title_badges,
                     :card_image_badge,
                     :card_image_badge_id,
                     :muted_usernames

  untrusted_attributes :bio_raw,
                       :bio_cooked,
                       :bio_excerpt,
                       :location,
                       :website,
                       :profile_background,
                       :card_background

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

  def bio_cooked
    object.user_profile.bio_processed
  end

  def website
    object.user_profile.website
  end

  def website_name
    website_host = URI(website.to_s).host rescue nil
    discourse_host = Discourse.current_hostname
    return if website_host.nil?
    if website_host == discourse_host
      # example.com == example.com
      website_host + URI(website.to_s).path
    elsif (website_host.split('.').length == discourse_host.split('.').length) && discourse_host.split('.').length > 2
      # www.example.com == forum.example.com
      website_host.split('.')[1..-1].join('.') == discourse_host.split('.')[1..-1].join('.') ? website_host + URI(website.to_s).path : website_host
    else
      # example.com == forum.example.com
      discourse_host.ends_with?("." << website_host) ? website_host + URI(website.to_s).path : website_host
    end
  end

  def include_website_name
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

  def card_background
    object.user_profile.card_background
  end

  def location
    object.user_profile.location
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

  def include_stats?
    !omit_stats == true
  end

  def stats
    UserAction.stats(object.id, scope)
  end

  # Needed because 'send_private_message_to_user' will always return false
  # when the current user is being serialized
  def can_send_private_messages
    scope.can_send_private_message?(Discourse.system_user)
  end

  def can_send_private_message_to_user
    scope.can_send_private_message?(object)
  end

  def bio_excerpt
    object.user_profile.bio_excerpt(350 , { keep_newlines: true, keep_emojis: true })
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

  def post_count
    object.user_stat.try(:post_count)
  end

  def can_be_deleted
    scope.can_delete_user?(object)
  end

  def can_delete_all_posts
    scope.can_delete_all_posts?(object)
  end

  ###
  ### PRIVATE ATTRIBUTES
  ###

  def auto_track_topics_after_msecs
    object.auto_track_topics_after_msecs || SiteSetting.default_other_auto_track_topics_after_msecs
  end

  def new_topic_duration_minutes
    object.new_topic_duration_minutes || SiteSetting.default_other_new_topic_duration_minutes
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

  def muted_usernames
    MutedUser.where(user_id: object.id).joins(:muted_user).pluck(:username)
  end

  def include_private_messages_stats?
    can_edit && !(omit_stats == true)
  end

  def private_messages_stats
    UserAction.private_messages_stats(object.id, scope)
  end

  def system_avatar_upload_id
    # should be left blank
  end

  def system_avatar_template
    User.system_avatar_template(object.username)
  end

  def gravatar_avatar_upload_id
    object.user_avatar.try(:gravatar_upload_id)
  end

  def gravatar_avatar_template
    return unless gravatar_upload_id = object.user_avatar.try(:gravatar_upload_id)
    User.avatar_template(object.username, gravatar_upload_id)
  end

  def custom_avatar_upload_id
    object.user_avatar.try(:custom_upload_id)
  end

  def custom_avatar_template
    return unless custom_upload_id = object.user_avatar.try(:custom_upload_id)
    User.avatar_template(object.username, custom_upload_id)
  end

  def has_title_badges
    object.badges.where(allow_title: true).count > 0
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

  def include_topic_post_count?
    topic_post_count.present?
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

  def pending_count
    0
  end

end
