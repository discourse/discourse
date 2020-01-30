# frozen_string_literal: true

class UserSerializer < UserCardSerializer

  attributes :bio_raw,
             :bio_cooked,
             :can_edit,
             :can_edit_username,
             :can_edit_email,
             :can_edit_name,
             :uploaded_avatar_id,
             :has_title_badges,
             :pending_count,
             :profile_view_count,
             :second_factor_enabled,
             :second_factor_backup_enabled,
             :second_factor_remaining_backup_codes,
             :associated_accounts,
             :profile_background_upload_url

  has_one :invited_by, embed: :object, serializer: BasicUserSerializer
  has_many :groups, embed: :object, serializer: BasicGroupSerializer
  has_many :group_users, embed: :object, serializer: BasicGroupUserSerializer
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
                     :system_avatar_upload_id,
                     :system_avatar_template,
                     :gravatar_avatar_upload_id,
                     :gravatar_avatar_template,
                     :custom_avatar_upload_id,
                     :custom_avatar_template,
                     :has_title_badges,
                     :muted_usernames,
                     :ignored_usernames,
                     :mailing_list_posts_per_day,
                     :can_change_bio,
                     :user_api_keys,
                     :user_auth_tokens

  untrusted_attributes :bio_raw,
                       :bio_cooked,
                       :profile_background_upload_url,

  ###
  ### ATTRIBUTES
  ###

  def mailing_list_posts_per_day
    val = Post.estimate_posts_per_day
    [val, SiteSetting.max_emails_per_day_per_user].min
  end

  def groups
    object.groups.order(:id)
      .visible_groups(scope.user).members_visible_groups(scope.user)
  end

  def group_users
    object.group_users.order(:group_id)
  end

  def include_associated_accounts?
    (object.id && object.id == scope.user.try(:id))
  end

  def include_second_factor_enabled?
    (object&.id == scope.user&.id) || scope.is_staff?
  end

  def second_factor_enabled
    object.totp_enabled? || object.security_keys_enabled?
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

  def bio_raw
    object.user_profile.bio_raw
  end

  def bio_cooked
    object.user_profile.bio_processed
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

  def ignored_usernames
    IgnoredUser.where(user_id: object.id).joins(:ignored_user).pluck(:username)
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

  def pending_count
    0
  end

  def profile_view_count
    object.user_profile.views
  end

  def profile_background_upload_url
    object.profile_background_upload&.url
  end

end
