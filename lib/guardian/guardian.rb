# The guardian is responsible for confirming access to various site resources and operations
class Guardian
  include TopicGuardian
  include PostGuardian
  include CategoryGuardian
  include UserGuardian

  class AnonymousUser
    def blank?; true; end
    def admin?; false; end
    def staff?; false; end
    def approved?; false; end
    def secure_category_ids; []; end
    def topic_create_allowed_category_ids; []; end
    def has_trust_level?(level); false; end
  end

  def initialize(user=nil)
    @user = user.presence || AnonymousUser.new
  end

  def user
    @user.presence
  end
  alias :current_user :user

  def is_staff?
    @user.staff?
  end

  def can_moderate?(obj)
    obj && is_staff?
  end
  alias :can_move_posts? :can_moderate?
  alias :can_see_flags? :can_moderate?
  alias :can_send_activation_email? :can_moderate?

  # Can we approve it?
  def can_approve?(target)
    is_staff? && target && not(target.approved?)
  end
  alias :can_activate? :can_approve?

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

  def can_invite_to?(object)
    authenticated? &&
    can_see?(object) &&
    (
      (!SiteSetting.must_approve_users? && @user.has_trust_level?(:regular)) ||
      is_staff?
    )
  end

  def can_see_private_messages?(user_id)
    is_staff? || (authenticated? && @user.id == user_id)
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

  # Can the user see the object?
  def can_see?(obj)
    if obj
      see_method = method_name_for :see, obj
      return (see_method ? send(see_method, obj) : true)
    end
  end

  # Can the user edit the obj
  def can_edit?(obj)
    if obj && authenticated?
      edit_method = method_name_for :edit, obj
      return (edit_method ? send(edit_method, obj) : true)
    end
  end

  # Can we delete the object
  def can_delete?(obj)
    if obj && authenticated?
      delete_method = method_name_for :delete, obj
      return (delete_method ? send(delete_method, obj) : true)
    end
  end

  def can_create?(klass, parent=nil)
    return false unless authenticated? && klass

    # If no parent is provided, we look for a can_i_create_klass?
    # custom method.
    #
    # If a parent is provided, we look for a method called
    # can_i_create_klass_on_parent?
    target = klass.name.underscore
    if parent.present?
      return false unless can_see?(parent)
      target << "_on_#{parent.class.name.underscore}"
    end
    create_method = :"can_create_#{target}?"

    return send(create_method, parent) if respond_to?(create_method)

    true
  end

  # Support for ensure_{blah}! methods.
  def method_missing(method, *args, &block)
    if method.to_s =~ /^ensure_(.*)\!$/
      can_method = :"#{Regexp.last_match[1]}?"

      if respond_to?(can_method)
        raise Discourse::InvalidAccess.new("#{can_method} failed") unless send(can_method, *args, &block)
        return
      end
    end

    super.method_missing(method, *args, &block)
  end

  # Make sure we can see the object. Will raise a NotFound if it's nil
  def ensure_can_see!(obj)
    raise Discourse::InvalidAccess.new("Can't see #{obj}") unless can_see?(obj)
  end

  def secure_category_ids
    @secure_category_ids ||= @user.secure_category_ids
  end

  private

  def authenticated?
    @user.present?
  end

  def is_admin?
    @user.admin?
  end

  def is_my_own?(obj)
    @user.present? &&
    (obj.respond_to?(:user) || obj.respond_to?(:user_id)) &&
    (obj.respond_to?(:user) ? obj.user == @user : true) &&
    (obj.respond_to?(:user_id) ? (obj.user_id == @user.id) : true)
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

end
