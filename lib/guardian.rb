# frozen_string_literal: true

require 'guardian/category_guardian'
require 'guardian/ensure_magic'
require 'guardian/post_guardian'
require 'guardian/bookmark_guardian'
require 'guardian/topic_guardian'
require 'guardian/user_guardian'
require 'guardian/post_revision_guardian'
require 'guardian/group_guardian'
require 'guardian/tag_guardian'

# The guardian is responsible for confirming access to various site resources and operations
class Guardian
  include EnsureMagic
  include CategoryGuardian
  include PostGuardian
  include BookmarkGuardian
  include TopicGuardian
  include UserGuardian
  include PostRevisionGuardian
  include GroupGuardian
  include TagGuardian

  class AnonymousUser
    def blank?
      true
    end
    def admin?
      false
    end
    def staff?
      false
    end
    def moderator?
      false
    end
    def anonymous?
      true
    end
    def approved?
      false
    end
    def staged?
      false
    end
    def silenced?
      false
    end
    def secure_category_ids
      []
    end
    def topic_create_allowed_category_ids
      []
    end
    def has_trust_level?(level)
      false
    end
    def has_trust_level_or_staff?(level)
      false
    end
    def email
      nil
    end
  end

  attr_reader :request

  def initialize(user = nil, request = nil)
    @user = user.presence || AnonymousUser.new
    @request = request
  end

  def user
    @user.presence
  end
  alias :current_user :user

  def anonymous?
    !authenticated?
  end

  def authenticated?
    @user.present?
  end

  def is_admin?
    @user.admin?
  end

  def is_staff?
    @user.staff?
  end

  def is_moderator?
    @user.moderator?
  end

  def is_category_group_moderator?(category)
    return false unless category
    return false unless authenticated?

    @is_category_group_moderator ||= begin
      SiteSetting.enable_category_group_moderation? &&
        category.present? &&
        category.reviewable_by_group_id.present? &&
        GroupUser.where(group_id: category.reviewable_by_group_id, user_id: @user.id).exists?
    end
  end

  def is_silenced?
    @user.silenced?
  end

  def is_developer?
    @user &&
    is_admin? &&
    (
      Rails.env.development? ||
      Developer.user_ids.include?(@user.id) ||
      (
        Rails.configuration.respond_to?(:developer_emails) &&
        Rails.configuration.developer_emails.include?(@user.email)
      )
    )
  end

  def is_staged?
    @user.staged?
  end

  def is_anonymous?
    @user.anonymous?
  end

  # Can the user see the object?
  def can_see?(obj)
    if obj
      see_method = method_name_for :see, obj
      (see_method ? public_send(see_method, obj) : true)
    end
  end

  def can_create?(klass, parent = nil)
    return false unless authenticated? && klass

    # If no parent is provided, we look for a can_create_klass?
    # custom method.
    #
    # If a parent is provided, we look for a method called
    # can_create_klass_on_parent?
    target = klass.name.underscore
    if parent.present?
      return false unless can_see?(parent)
      target << "_on_#{parent.class.name.underscore}"
    end
    create_method = :"can_create_#{target}?"

    return public_send(create_method, parent) if respond_to?(create_method)

    true
  end

  def can_enable_safe_mode?
    SiteSetting.enable_safe_mode? || is_staff?
  end

  # Can the user edit the obj
  def can_edit?(obj)
    can_do?(:edit, obj)
  end

  # Can we delete the object
  def can_delete?(obj)
    can_do?(:delete, obj)
  end

  def can_permanently_delete?(obj)
    can_do?(:permanently_delete, obj)
  end

  def can_moderate?(obj)
    obj && authenticated? && !is_silenced? && (
      is_staff? ||
      (obj.is_a?(Topic) && @user.has_trust_level?(TrustLevel[4]) && can_see_topic?(obj))
    )
  end
  alias :can_see_flags? :can_moderate?

  def can_tag?(topic)
    return false if topic.blank?

    topic.private_message? ? can_tag_pms? : can_tag_topics?
  end

  def can_see_tags?(topic)
    SiteSetting.tagging_enabled && topic.present? && (!topic.private_message? || can_tag_pms?)
  end

  def can_send_activation_email?(user)
    user && is_staff? && !SiteSetting.must_approve_users?
  end

  def can_grant_badges?(_user)
    SiteSetting.enable_badges && is_staff?
  end

  def can_delete_reviewable_queued_post?(reviewable)
    reviewable.present? &&
      authenticated? &&
      reviewable.created_by_id == @user.id
  end

  def can_see_group?(group)
    group.present? && can_see_groups?([group])
  end

  def can_see_group_members?(group)
    return false if group.blank?
    return true if is_admin? || group.members_visibility_level == Group.visibility_levels[:public]
    return true if is_staff? && group.members_visibility_level == Group.visibility_levels[:staff]
    return true if is_staff? && group.members_visibility_level == Group.visibility_levels[:members]
    return true if authenticated? && group.members_visibility_level == Group.visibility_levels[:logged_on_users]
    return false if user.blank?

    return false unless membership = GroupUser.find_by(group_id: group.id, user_id: user.id)
    return true if membership.owner

    return false if group.members_visibility_level == Group.visibility_levels[:owners]
    return false if group.members_visibility_level == Group.visibility_levels[:staff]

    true
  end

  def can_see_groups?(groups)
    return false if groups.blank?
    return true if is_admin? || groups.all? { |g| g.visibility_level == Group.visibility_levels[:public] }
    return true if is_staff? && groups.all? { |g| g.visibility_level == Group.visibility_levels[:staff] }
    return true if is_staff? && groups.all? { |g| g.visibility_level == Group.visibility_levels[:members] }
    return true if authenticated? && groups.all? { |g| g.visibility_level == Group.visibility_levels[:logged_on_users] }
    return false if user.blank?

    memberships = GroupUser.where(group: groups, user_id: user.id).pluck(:owner)
    return false if memberships.size < groups.size
    return true if memberships.all? # owner of all groups

    return false if groups.all? { |g| g.visibility_level == Group.visibility_levels[:owners] }
    return false if groups.all? { |g| g.visibility_level == Group.visibility_levels[:staff] }

    true
  end

  def can_see_groups_members?(groups)
    return false if groups.blank?

    requested_group_ids = groups.map(&:id) # Can't use pluck, groups could be a regular array
    matching_group_ids = Group.where(id: requested_group_ids).members_visible_groups(user).pluck(:id)

    matching_group_ids.sort == requested_group_ids.sort
  end

  # Can we impersonate this user?
  def can_impersonate?(target)
    target &&

    # You must be an admin to impersonate
    is_admin? &&

    # You may not impersonate other admins unless you are a dev
    (!target.admin? || is_developer?)

    # Additionally, you may not impersonate yourself;
    # but the two tests for different admin statuses
    # make it impossible to be the same user.
  end

  def can_view_action_logs?(target)
    target.present? && is_staff?
  end

  # Can we approve it?
  def can_approve?(target)
    is_staff? && target && target.active? && !target.approved?
  end

  def can_activate?(target)
    is_staff? && target && not(target.active?)
  end

  def can_suspend?(user)
    user && is_staff? && user.regular?
  end
  alias :can_deactivate? :can_suspend?

  def can_revoke_admin?(admin)
    can_administer_user?(admin) && admin.admin?
  end

  def can_grant_admin?(user)
    can_administer_user?(user) && !user.admin?
  end

  def can_revoke_moderation?(moderator)
    can_administer?(moderator) && moderator.moderator?
  end

  def can_grant_moderation?(user)
    can_administer?(user) && !user.moderator?
  end

  def can_grant_title?(user, title = nil)
    return true if user && is_staff?
    return false if title.nil?
    return true if title.empty? # A title set to '(none)' in the UI is an empty string
    return false if user != @user

    return true if user.badges
      .where(allow_title: true)
      .pluck(:name)
      .any? { |name| Badge.display_name(name) == title }

    user.groups.where(title: title).exists?
  end

  def can_use_primary_group?(user, group_id = nil)
    return false if !user || !group_id
    group = Group.find_by(id: group_id.to_i)

    user.group_ids.include?(group_id.to_i) &&
    (group ? !group.automatic : false)
  end

  def can_use_flair_group?(user, group_id = nil)
    return false if !user || !group_id || !user.group_ids.include?(group_id.to_i)
    flair_icon, flair_upload_id = Group.where(id: group_id.to_i).pluck_first(:flair_icon, :flair_upload_id)
    flair_icon.present? || flair_upload_id.present?
  end

  def can_change_primary_group?(user)
    user && is_staff?
  end

  def can_change_trust_level?(user)
    user && is_staff?
  end

  # Support sites that have to approve users
  def can_access_forum?
    return true unless SiteSetting.must_approve_users?
    return false if anonymous?

    # Staff can't lock themselves out of a site
    return true if is_staff?

    @user.approved?
  end

  def can_see_invite_details?(user)
    is_staff? || is_me?(user)
  end

  def can_see_invite_emails?(user)
    is_staff? || is_me?(user)
  end

  def can_invite_to_forum?(groups = nil)
    authenticated? &&
    (is_staff? || SiteSetting.max_invites_per_day.to_i.positive?) &&
    (is_staff? || @user.has_trust_level?(SiteSetting.min_trust_level_to_allow_invite.to_i)) &&
    (is_admin? || groups.blank? || groups.all? { |g| can_edit_group?(g) })
  end

  def can_invite_to?(object, groups = nil)
    return false if !authenticated?
    return false if !object.is_a?(Topic) || !can_see?(object)
    return false if groups.present?

    if object.is_a?(Topic)
      if object.private_message?
        return true if is_admin?
        return false unless SiteSetting.enable_personal_messages?
        return false if object.reached_recipients_limit? && !is_staff?
      end

      if (category = object.category) && category.read_restricted
        return category.groups&.where(automatic: false).any? { |g| can_edit_group?(g) }
      end
    end

    true
  end

  def can_invite_via_email?(object)
    return false if !can_invite_to_forum?
    return false if !can_invite_to?(object)

    (SiteSetting.enable_local_logins || SiteSetting.enable_discourse_connect) &&
      (!SiteSetting.must_approve_users? || is_staff?)
  end

  def can_bulk_invite_to_forum?(user)
    user.admin?
  end

  def can_resend_all_invites?(user)
    user.staff?
  end

  def can_destroy_all_invites?(user)
    user.staff?
  end

  def can_see_private_messages?(user_id)
    is_admin? || (authenticated? && @user.id == user_id)
  end

  def can_invite_group_to_private_message?(group, topic)
    can_see_topic?(topic) &&
    can_send_private_message?(group)
  end

  def can_send_private_message?(target, notify_moderators: false)
    is_user = target.is_a?(User)
    is_group = target.is_a?(Group)

    (is_group || is_user) &&
    # User is authenticated
    authenticated? &&
    # Have to be a basic level at least
    (is_group || @user.has_trust_level?(SiteSetting.min_trust_to_send_messages) || notify_moderators) &&
    # User disabled private message
    (is_staff? || is_group || target.user_option.allow_private_messages) &&
    # PMs are enabled
    (is_staff? || SiteSetting.enable_personal_messages || notify_moderators) &&
    # Can't send PMs to suspended users
    (is_staff? || is_group || !target.suspended?) &&
    # Check group messageable level
    (is_staff? || is_user || Group.messageable(@user).where(id: target.id).exists? || notify_moderators) &&
    # Silenced users can only send PM to staff
    (!is_silenced? || target.staff?)
  end

  def can_send_private_messages_to_email?
    # Staged users must be enabled to create a temporary user.
    return false if !SiteSetting.enable_staged_users
    # User is authenticated
    return false if !authenticated?
    # User is trusted enough
    SiteSetting.enable_personal_messages && @user.has_trust_level_or_staff?(SiteSetting.min_trust_to_send_email_messages)
  end

  def can_export_entity?(entity)
    return false if anonymous?
    return true if is_admin?
    return entity != 'user_list' if is_moderator?

    # Regular users can only export their archives
    return false unless entity == "user_archive"
    UserExport.where(user_id: @user.id, created_at: (Time.zone.now.beginning_of_day..Time.zone.now.end_of_day)).count == 0
  end

  def can_mute_user?(target_user)
    can_mute_users? &&
      @user.id != target_user.id &&
      !target_user.staff?
  end

  def can_mute_users?
    return false if anonymous?
    @user.staff? || @user.trust_level >= TrustLevel.levels[:basic]
  end

  def can_ignore_user?(target_user)
    can_ignore_users? && @user.id != target_user.id && !target_user.staff?
  end

  def can_ignore_users?
    return false if anonymous?
    @user.staff? || @user.has_trust_level?(SiteSetting.min_trust_level_to_allow_ignore.to_i)
  end

  def allowed_theme_repo_import?(repo)
    return false if !@user.admin?

    allowed_repos = GlobalSetting.allowed_theme_repos
    if !allowed_repos.blank?
      urls = allowed_repos.split(",").map(&:strip)
      return urls.include?(repo)
    end

    true
  end

  def allow_themes?(theme_ids, include_preview: false)
    return true if theme_ids.blank?

    if allowed_theme_ids = Theme.allowed_remote_theme_ids
      if (theme_ids - allowed_theme_ids).present?
        return false
      end
    end

    if include_preview && is_staff? && (theme_ids - Theme.theme_ids).blank?
      return true
    end

    parent = theme_ids.first
    components = theme_ids[1..-1] || []

    Theme.user_theme_ids.include?(parent) &&
      (components - Theme.components_for(parent)).empty?
  end

  def can_publish_page?(topic)
    return false if !SiteSetting.enable_page_publishing?
    return false if SiteSetting.secure_media?
    return false if topic.blank?
    return false if topic.private_message?
    return false unless can_see_topic?(topic)
    is_staff?
  end

  def can_see_about_stats?
    true
  end

  def can_see_site_contact_details?
    !SiteSetting.login_required? || authenticated?
  end

  def auth_token
    return if !request

    token = Auth::DefaultCurrentUserProvider.find_v0_auth_cookie(request).presence

    if !token
      cookie = Auth::DefaultCurrentUserProvider.find_v1_auth_cookie(request.env)
      token = cookie[:token] if cookie
    end

    UserAuthToken.hash_token(token) if token
  end

  def can_mention_here?
    return false if SiteSetting.here_mention.blank?
    return false if SiteSetting.max_here_mentioned < 1
    return false if !authenticated?
    return false if User.where(username_lower: SiteSetting.here_mention).exists?

    @user.has_trust_level_or_staff?(SiteSetting.min_trust_level_for_here_mention)
  end

  def is_me?(other)
    other && authenticated? && other.is_a?(User) && @user == other
  end

  private

  def is_my_own?(obj)

    unless anonymous?
      return obj.user_id == @user.id if obj.respond_to?(:user_id) && obj.user_id && @user.id
      return obj.user == @user if obj.respond_to?(:user)
    end

    false
  end

  def is_not_me?(other)
    @user.blank? || !is_me?(other)
  end

  def can_administer?(obj)
    is_admin? && obj.present? && obj.id&.positive?
  end

  def can_administer_user?(other_user)
    can_administer?(other_user) && is_not_me?(other_user)
  end

  def method_name_for(action, obj)
    method_name = :"can_#{action}_#{obj.class.name.underscore}?"
    return method_name if respond_to?(method_name)
  end

  def can_do?(action, obj)
    if obj && authenticated?
      action_method = method_name_for action, obj
      (action_method ? public_send(action_method, obj) : true)
    else
      false
    end
  end

end
