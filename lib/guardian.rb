require_dependency 'guardian/category_guardian'
require_dependency 'guardian/ensure_magic'
require_dependency 'guardian/post_guardian'
require_dependency 'guardian/topic_guardian'
# The guardian is responsible for confirming access to various site resources and operations
class Guardian
  include EnsureMagic
  include CategoryGuardian
  include PostGuardain
  include TopicGuardian
    
  class AnonymousUser
    def blank?; true; end
    def admin?; false; end
    def staff?; false; end
    def approved?; false; end
    def secure_category_ids; []; end
    def topic_create_allowed_category_ids; []; end
    def has_trust_level?(level); false; end
    def email; nil; end
  end
  def initialize(user=nil)
    @user = user.presence || AnonymousUser.new
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

  def is_developer?
    @user &&
    is_admin? &&
    (Rails.env.development? ||
      (
        Rails.configuration.respond_to?(:developer_emails) &&
        Rails.configuration.developer_emails.include?(@user.email)
      )
    )
  end

  # Can the user see the object?
  def can_see?(obj)
    if obj
      see_method = method_name_for :see, obj
      return (see_method ? send(see_method, obj) : true)
    end
  end

  # Can the user edit the obj
  def can_edit?(obj)
    can_do?(:edit, obj)
  end

  # Can we delete the object
  def can_delete?(obj)
    can_do?(:delete, obj)
  end

  def can_moderate?(obj)
    obj && is_staff?
  end
  alias :can_move_posts? :can_moderate?
  alias :can_see_flags? :can_moderate?
  alias :can_send_activation_email? :can_moderate?



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

  # Can we approve it?
  def can_approve?(target)
    is_staff? && target && not(target.approved?)
  end
  alias :can_activate? :can_approve?

  def can_suspend?(user)
    user && is_staff? && user.regular?
  end
  alias :can_deactivate? :can_suspend?

  def can_revoke_admin?(admin)
    can_administer_user?(admin) && admin.admin?
  end

  def can_grant_admin?(user)
    can_administer_user?(user) && not(user.admin?)
  end

  def can_revoke_moderation?(moderator)
    can_administer?(moderator) && moderator.moderator?
  end

  def can_grant_moderation?(user)
    can_administer?(user) && not(user.moderator?)
  end

  def can_grant_title?(user)
    user && is_staff?
  end

  def can_change_trust_level?(user)
    user && is_staff?
  end

  def can_block_user?(user)
    user && is_staff? && not(user.staff?)
  end

  def can_unblock_user?(user)
    user && is_staff?
  end

  def can_delete_user?(user)
    user && is_staff? && !user.admin? && user.created_at > SiteSetting.delete_user_max_age.to_i.days.ago
  end

  # Support sites that have to approve users
  def can_access_forum?
    return true unless SiteSetting.must_approve_users?
    return false unless @user

    # Staff can't lock themselves out of a site
    return true if is_staff?

    @user.approved?
  end

  def can_see_pending_invites_from?(user)
    is_me?(user)
  end

  def can_invite_to_forum?
    authenticated? &&
    (
      (!SiteSetting.must_approve_users? && @user.has_trust_level?(:regular)) ||
      is_staff?
    )
  end

  def can_invite_to?(object)
    can_see?(object) && can_invite_to_forum?
  end

  def can_see_private_messages?(user_id)
    is_staff? || (authenticated? && @user.id == user_id)
  end

  def can_edit_user?(user)
    is_me?(user) || is_staff?
  end

  def can_edit_username?(user)
    return true if is_staff?
    return false if SiteSetting.username_change_period <= 0
    is_me?(user) && (user.post_count == 0 || user.created_at > SiteSetting.username_change_period.days.ago)
  end

  def can_edit_email?(user)
    return true if is_staff?
    return false unless SiteSetting.email_editable?
    can_edit?(user)
  end

  def can_send_private_message?(target)
    (User === target || Group === target) &&
    authenticated? &&

    # Can't send message to yourself
    is_not_me?(target) &&

    # Have to be a basic level at least
    @user.has_trust_level?(:basic) &&

    SiteSetting.enable_private_messages
  end

  private

  def is_my_own?(obj)

    unless anonymous?
      return obj.user_id == @user.id if obj.respond_to?(:user_id) && obj.user_id && @user.id
      return obj.user == @user if obj.respond_to?(:user)
    end

    false
  end

  def is_me?(other)
    other && authenticated? && User === other && @user == other
  end

  def is_not_me?(other)
    @user.blank? || !is_me?(other)
  end

  def can_administer?(obj)
    is_admin? && obj.present?
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
      return (action_method ? send(action_method, obj) : true)
    else
      false
    end
  end

end
