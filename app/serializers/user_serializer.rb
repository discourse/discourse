# frozen_string_literal: true

class UserSerializer < UserCardSerializer
  include UserTagNotificationsMixin
  include UserSidebarMixin

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
             :profile_background_upload_url,
             :can_upload_profile_header,
             :can_upload_user_card_background

  has_one :invited_by, embed: :object, serializer: BasicUserSerializer
  has_many :groups, embed: :object, serializer: BasicGroupSerializer
  has_many :group_users, embed: :object, serializer: BasicGroupUserSerializer
  has_one :user_option, embed: :object, serializer: UserOptionSerializer

  def include_user_option?
    can_edit
  end

  staff_attributes :post_count, :can_be_deleted, :can_delete_all_posts

  private_attributes :locale,
                     :muted_category_ids,
                     :regular_category_ids,
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
                     :can_mute_users,
                     :ignored_usernames,
                     :can_ignore_users,
                     :allowed_pm_usernames,
                     :mailing_list_posts_per_day,
                     :can_change_bio,
                     :can_change_location,
                     :can_change_website,
                     :can_change_tracking_preferences,
                     :user_api_keys,
                     :user_passkeys,
                     :user_auth_tokens,
                     :user_notification_schedule,
                     :use_logo_small_as_avatar,
                     :sidebar_tags,
                     :sidebar_category_ids,
                     :display_sidebar_tags,
                     :can_pick_theme_with_custom_homepage

  untrusted_attributes :bio_raw, :bio_cooked, :profile_background_upload_url

  ###
  ### ATTRIBUTES
  ###
  #
  def user_notification_schedule
    UserNotificationScheduleSerializer.new(
      object.user_notification_schedule,
      scope: scope,
      root: false,
    ).as_json || UserNotificationSchedule::DEFAULT
  end

  def mailing_list_posts_per_day
    val = Post.estimate_posts_per_day
    [val, SiteSetting.max_emails_per_day_per_user].min
  end

  def groups
    object.groups.order(:id).visible_groups(scope.user)
  end

  def group_users
    object.group_users.order(:group_id)
  end

  def include_group_users?
    user_is_current_user || scope.is_admin?
  end

  def include_associated_accounts?
    user_is_current_user
  end

  def include_second_factor_enabled?
    user_is_current_user || scope.is_admin?
  end

  def second_factor_enabled
    object.totp_enabled? || object.security_keys_enabled?
  end

  def include_second_factor_backup_enabled?
    user_is_current_user
  end

  def second_factor_backup_enabled
    object.backup_codes_enabled?
  end

  def include_second_factor_remaining_backup_codes?
    user_is_current_user && object.backup_codes_enabled?
  end

  def second_factor_remaining_backup_codes
    object.remaining_backup_codes
  end

  def can_change_bio
    !(SiteSetting.enable_discourse_connect && SiteSetting.discourse_connect_overrides_bio)
  end

  def can_change_location
    !(SiteSetting.enable_discourse_connect && SiteSetting.discourse_connect_overrides_location)
  end

  def can_change_website
    !(SiteSetting.enable_discourse_connect && SiteSetting.discourse_connect_overrides_website)
  end

  def can_change_tracking_preferences
    scope.can_change_tracking_preferences?(object)
  end

  def user_api_keys
    keys =
      object
        .user_api_keys
        .where(revoked_at: nil)
        .map do |k|
          {
            id: k.id,
            application_name: k.application_name,
            scopes: k.scopes.map { |s| I18n.t("user_api_key.scopes.#{s.name}") },
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
      scope: scope,
    )
  end

  def user_passkeys
    UserSecurityKey
      .where(user_id: object.id, factor_type: UserSecurityKey.factor_types[:first_factor])
      .order("created_at ASC")
      .map do |usk|
        { id: usk.id, name: usk.name, last_used: usk.last_used, created_at: usk.created_at }
      end
  end

  def include_user_passkeys?
    SiteSetting.enable_passkeys? && user_is_current_user
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

  def can_upload_profile_header
    scope.can_upload_profile_header?(object)
  end

  def can_upload_user_card_background
    scope.can_upload_user_card_background?(object)
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
  def muted_category_ids
    categories_with_notification_level(:muted)
  end

  def regular_category_ids
    categories_with_notification_level(:regular)
  end

  def tracked_category_ids
    categories_with_notification_level(:tracking)
  end

  def watched_category_ids
    categories_with_notification_level(:watching)
  end

  def watched_first_post_category_ids
    categories_with_notification_level(:watching_first_post)
  end

  def muted_usernames
    MutedUser.where(user_id: object.id).joins(:muted_user).pluck(:username)
  end

  def can_mute_users
    scope.can_mute_users?
  end

  def ignored_usernames
    IgnoredUser.where(user_id: object.id).joins(:ignored_user).pluck(:username)
  end

  def can_ignore_users
    scope.can_ignore_users?
  end

  def allowed_pm_usernames
    AllowedPmUser.where(user_id: object.id).joins(:allowed_pm_user).pluck(:username)
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

  def use_logo_small_as_avatar
    object.is_system_user? && SiteSetting.logo_small &&
      SiteSetting.use_site_small_logo_as_system_avatar
  end

  def can_pick_theme_with_custom_homepage
    ThemeModifierHelper.new(theme_ids: Theme.enabled_theme_and_component_ids).custom_homepage
  end

  private

  def custom_field_keys
    fields = super

    fields += DiscoursePluginRegistry.serialized_current_user_fields.to_a if scope.can_edit?(object)

    fields
  end
end
