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
             :custom_fields,
             :user_fields,
             :topic_post_count,
             :pending_count,
             :profile_view_count,
             :time_read,
             :recent_time_read,
             :primary_group_name,
             :primary_group_flair_url,
             :primary_group_flair_bg_color,
             :primary_group_flair_color,
             :staged,
             :second_factor_enabled,
             :second_factor_backup_enabled,
             :second_factor_remaining_backup_codes,
             :associated_accounts

  has_one :invited_by, embed: :object, serializer: BasicUserSerializer
  has_many :groups, embed: :object, serializer: BasicGroupSerializer
  has_many :group_users, embed: :object, serializer: BasicGroupUserSerializer
  has_many :featured_user_badges, embed: :ids, serializer: UserBadgeSerializer, root: :user_badges
  has_one :user_option, embed: :object, serializer: UserOptionSerializer

  def include_user_option?
    can_edit
  end

  staff_attributes :post_count,
                   :can_be_deleted,
                   :can_delete_all_posts

  private_attributes :locale,
                     :muted_category_ids,
                     :watched_tags,
                     :watching_first_post_tags,
                     :tracked_tags,
                     :muted_tags,
                     :tracked_category_ids,
                     :watched_category_ids,
                     :watched_first_post_category_ids,
                     :private_messages_stats,
                     :system_avatar_upload_id,
                     :system_avatar_template,
                     :gravatar_avatar_upload_id,
                     :gravatar_avatar_template,
                     :custom_avatar_upload_id,
                     :custom_avatar_template,
                     :has_title_badges,
                     :muted_usernames,
                     :mailing_list_posts_per_day,
                     :can_change_bio,
                     :user_api_keys,
                     :user_auth_tokens,
                     :user_auth_token_logs

  untrusted_attributes :bio_raw,
                       :bio_cooked,
                       :bio_excerpt,
                       :location,
                       :website,
                       :website_name,
                       :profile_background,
                       :card_background

  ###
  ### ATTRIBUTES
  ###

  def mailing_list_posts_per_day
    val = Post.estimate_posts_per_day
    [val, SiteSetting.max_emails_per_day_per_user].min
  end

  def groups
    object.groups.order(:id)
      .visible_groups(scope.user)
  end

  def group_users
    object.group_users.order(:group_id)
  end

  def include_email?
    (object.id && object.id == scope.user.try(:id)) ||
      (scope.is_staff? && object.staged?)
  end

  def include_associated_accounts?
    (object.id && object.id == scope.user.try(:id))
  end

  def include_second_factor_enabled?
    (object&.id == scope.user&.id) || scope.is_staff?
  end

  def second_factor_enabled
    object.totp_enabled?
  end

  def include_second_factor_backup_enabled?
    object&.id == scope.user&.id
  end

  def second_factor_backup_enabled
    object.backup_codes_enabled?
  end

  def include_second_factor_remaining_backup_codes?
    (object&.id == scope.user&.id) && object.backup_codes_enabled?
  end

  def second_factor_remaining_backup_codes
    object.remaining_backup_codes
  end

  def can_change_bio
    !(SiteSetting.enable_sso && SiteSetting.sso_overrides_bio)
  end

  def user_api_keys
    keys = object.user_api_keys.where(revoked_at: nil).map do |k|
      {
        id: k.id,
        application_name: k.application_name,
        scopes: k.scopes.map { |s| I18n.t("user_api_key.scopes.#{s}") },
        created_at: k.created_at,
        last_used_at: k.last_used_at,
      }
    end

    keys.sort! { |a, b| a[:last_used_at].to_time <=> b[:last_used_at].to_time }
    keys.length > 0 ? keys : nil
  end

  def user_auth_tokens
    ActiveModel::ArraySerializer.new(
      object.user_auth_tokens,
      each_serializer: UserAuthTokenSerializer,
      scope: scope
    )
  end

  def user_auth_token_logs
    ActiveModel::ArraySerializer.new(
      object.user_auth_token_logs.where(
        action: UserAuthToken::USER_ACTIONS
      ).order(:created_at).reverse_order,
      each_serializer: UserAuthTokenLogSerializer
    )
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
    uri = begin
      URI(website.to_s)
    rescue URI::Error
    end

    return if uri.nil? || uri.host.nil?
    uri.host.sub(/^www\./, '') + uri.path
  end

  def include_website_name
    website.present?
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
    scope.can_send_private_message?(object) && scope.current_user != object
  end

  def bio_excerpt
    object.user_profile.bio_excerpt(350 , keep_newlines: true, keep_emoji_images: true)
  end

  def include_suspend_reason?
    scope.can_see_suspension_reason?(object) && object.suspended?
  end

  def include_suspended_till?
    object.suspended?
  end

  def primary_group_name
    object.primary_group.try(:name)
  end

  def primary_group_flair_url
    object.try(:primary_group).try(:flair_url)
  end

  def primary_group_flair_bg_color
    object.try(:primary_group).try(:flair_bg_color)
  end

  def primary_group_flair_color
    object.try(:primary_group).try(:flair_color)
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
  def muted_tags
    TagUser.lookup(object, :muted).joins(:tag).pluck('tags.name')
  end

  def tracked_tags
    TagUser.lookup(object, :tracking).joins(:tag).pluck('tags.name')
  end

  def watching_first_post_tags
    TagUser.lookup(object, :watching_first_post).joins(:tag).pluck('tags.name')
  end

  def watched_tags
    TagUser.lookup(object, :watching).joins(:tag).pluck('tags.name')
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

  def watched_first_post_category_ids
    CategoryUser.lookup(object, :watching_first_post).pluck(:category_id)
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

  def include_gravatar_avatar_upload_id?
    object.user_avatar&.gravatar_upload_id
  end

  def gravatar_avatar_upload_id
    object.user_avatar.gravatar_upload_id
  end

  def include_gravatar_avatar_template?
    include_gravatar_avatar_upload_id?
  end

  def gravatar_avatar_template
    User.avatar_template(object.username, object.user_avatar.gravatar_upload_id)
  end

  def include_custom_avatar_upload_id?
    object.user_avatar&.custom_upload_id
  end

  def custom_avatar_upload_id
    object.user_avatar.custom_upload_id
  end

  def include_custom_avatar_template?
    include_custom_avatar_upload_id?
  end

  def custom_avatar_template
    User.avatar_template(object.username, object.user_avatar.custom_upload_id)
  end

  def has_title_badges
    object.badges.where(allow_title: true).exists?
  end

  def user_fields
    allowed_keys = scope.allowed_user_field_ids(object).map(&:to_s)
    object.user_fields&.select { |k, v| allowed_keys.include?(k) }
  end

  def include_user_fields?
    user_fields.present?
  end

  def include_topic_post_count?
    topic_post_count.present?
  end

  def custom_fields
    fields = User.whitelisted_user_custom_fields(scope)

    if scope.can_edit?(object)
      fields += DiscoursePluginRegistry.serialized_current_user_fields.to_a
    end

    if fields.present?
      User.custom_fields_for_ids([object.id], fields)[object.id] || {}
    else
      {}
    end
  end

  def pending_count
    0
  end

  def profile_view_count
    object.user_profile.views
  end

  def time_read
    object.user_stat&.time_read
  end

  def recent_time_read
    time = object.recent_time_read
  end

  def include_staged?
    scope.is_staff?
  end

end
