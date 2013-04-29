# The guardian is responsible for confirming access to various site resources and operations
class Guardian

  attr_reader :user

  def initialize(user=nil)
    @user = user
  end

  def current_user
    @user
  end

  def is_admin?
    @user && @user.admin?
  end

  def is_moderator?
    @user && @user.moderator?
  end

  # Can the user see the object?
  def can_see?(obj)
    return false if obj.blank?

    see_method = :"can_see_#{obj.class.name.underscore}?"
    return send(see_method, obj) if respond_to?(see_method)

    return true
  end

  # Can the user edit the obj
  def can_edit?(obj)
    return false if obj.blank?
    return false if @user.blank?

    edit_method = :"can_edit_#{obj.class.name.underscore}?"
    return send(edit_method, obj) if respond_to?(edit_method)

    true
  end

  # Can we delete the object
  def can_delete?(obj)
    return false if obj.blank?
    return false if @user.blank?

    delete_method = :"can_delete_#{obj.class.name.underscore}?"
    return send(delete_method, obj) if respond_to?(delete_method)

    true
  end

  def can_moderate?(obj)
    return false if obj.blank?
    return false if @user.blank?
    @user.moderator?
  end
  alias :can_move_posts? :can_moderate?
  alias :can_see_flags? :can_moderate?

  # Can the user create a topic in the forum
  def can_create?(klass, parent=nil)
    return false if klass.blank?
    return false if @user.blank?

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

  # Can we impersonate this user?
  def can_impersonate?(target)
    return false if target.blank?
    return false if @user.blank?

    # You must be an admin to impersonate
    return false unless @user.admin?

    # You may not impersonate other admins
    return false if target.admin?

    # You may not impersonate yourself
    return false if @user == target

    true
  end

  # Can we approve it?
  def can_approve?(target)
    return false if target.blank?
    return false if @user.blank?
    return false if target.approved?
    @user.moderator?
  end

  def can_ban?(user)
    return false if user.blank?
    return false unless @user.try(:admin?)
    return false if user.admin?
    true
  end

  def can_clear_flags?(post)
    return false if @user.blank?
    return false if post.blank?
    @user.moderator?
  end

  def can_revoke_admin?(admin)
    return false unless @user.try(:admin?)
    return false if admin.blank?
    return false if @user.id == admin.id
    return false unless admin.admin?
    true
  end

  def can_grant_admin?(user)
    return false unless @user.try(:admin?)
    return false if user.blank?
    return false if @user.id == user.id
    return false if user.admin?
    true
  end

  def can_revoke_moderation?(moderator)
    return false unless @user.try(:admin?)
    return false if moderator.blank?
    return false if @user.id == moderator.id
    return false unless moderator.moderator?
    true
  end

  def can_grant_moderation?(user)
    return false unless @user.try(:admin?)
    return false if user.blank?
    return false if @user.id == user.id
    return false if user.admin?
    return false if user.moderator?
    true
  end

  def can_delete_user?(user_to_delete)
    return false unless @user.try(:admin?)
    return false if user_to_delete.blank?
    return false if user_to_delete.post_count > 0
    true
  end

  # Can we see who acted on a post in a particular way?
  def can_see_post_actors?(topic, post_action_type_id)
    return false unless topic.present?

    type_symbol = PostActionType.types[post_action_type_id]
    return false if type_symbol == :bookmark
    return can_see_flags?(topic) if PostActionType.is_flag?(type_symbol)

    if type_symbol == :vote
      # We can see votes if the topic allows for public voting
      return false if topic.has_meta_data_boolean?(:private_poll)
    end

    true
  end

  # Support sites that have to approve users
  def can_access_forum?
    return true unless SiteSetting.must_approve_users?
    return false if user.blank?

    # Admins can't lock themselves out of a site
    return true if user.admin?

    user.approved?
  end

  def can_see_pending_invites_from?(user)
    return false if user.blank?
    return false if @user.blank?
    return user == @user
  end

  # For now, can_invite_to is basically can_see?
  def can_invite_to?(object)
    return false if @user.blank?
    return false unless can_see?(object)
    return false if SiteSetting.must_approve_users?
    @user.has_trust_level?(:regular) || @user.moderator?
  end


  def can_see_deleted_posts?
    return true if is_admin?
    false
  end

  def can_see_private_messages?(user_id)
    return true if is_admin?
    return false if @user.blank?
    @user.id == user_id
  end

  def can_delete_all_posts?(user)
    return false unless is_admin?
    return false if user.created_at < 7.days.ago

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

  # Creating Methods
  def can_create_category?(parent)
    @user.moderator?
  end

  def can_create_post_on_topic?(topic)
    return true if @user.moderator?
    return false if topic.closed?
    return false if topic.archived?
    true
  end

  # Editing Methods
  def can_edit_category?(category)
    @user.moderator?
  end

  def can_edit_post?(post)
    return true if @user.moderator?
    return false if post.topic.archived?
    (post.user == @user)
  end

  def can_edit_user?(user)
    return true if user == @user
    @user.admin?
  end

  def can_edit_topic?(topic)
    return true if @user.moderator?
    return true if topic.user == @user
    false
  end

  # Deleting Methods
  def can_delete_post?(post)
    # Can't delete the first post
    return false if post.post_number == 1

    # You can delete your own posts
    return !post.user_deleted? if post.user == @user

    @user.moderator?
  end

  # Recovery Method
  def can_recover_post?(post)
    return false if @user.blank?
    @user.moderator?
  end

  def can_delete_category?(category)
    return false unless @user.moderator?
    return category.topic_count == 0
  end

  def can_delete_topic?(topic)
    return false unless @user.moderator?
    return false if Category.exists?(topic_id: topic.id)
    true
  end

  def can_delete_post_action?(post_action)

    # You can only undo your own actions
    return false unless @user
    return false unless post_action.user_id == @user.id
    return false if post_action.is_private_message?

    # Make sure they want to delete it within the window
    return post_action.created_at > SiteSetting.post_undo_action_window_mins.minutes.ago
  end

  def can_send_private_message?(target_user)
    return false unless User === target_user
    return false if @user.blank?

    # Can't send message to yourself
    return false if @user.id == target_user.id

    # Have to be a basic level at least
    return false unless @user.has_trust_level?(:basic)

    SiteSetting.enable_private_messages
  end

  def can_reply_as_new_topic?(topic)
    return false if @user.blank?
    return false if topic.blank?
    return false if topic.private_message?

    @user.has_trust_level?(:basic)
  end

  def can_see_topic?(topic)
    return false unless topic

    return true if @user && @user.moderator?
    return false if topic.deleted_at.present?

    if topic.category && topic.category.secure
      return false unless @user && can_see_category?(topic.category)
    end

    if topic.private_message?
      return false if @user.blank?
      return true if topic.allowed_users.include?(@user)
      return is_admin?
    end
    true
  end

  def can_see_post?(post)
    return false unless post

    return true if @user && @user.moderator?
    return false if post.deleted_at.present?

    can_see_topic?(post.topic)
  end

  def can_see_category?(category)
    return true unless category.secure
    return false unless @user

    @user.secure_category_ids.include?(category.id)
  end

  def can_vote?(post, opts={})
    post_can_act?(post,:vote, opts)
  end

  # Can the user act on the post in a particular way.
  #  taken_actions = the list of actions the user has already taken
  def post_can_act?(post, action_key, opts={})
    return false if @user.blank?
    return false if post.blank?
    return false if post.topic.archived?

    taken = opts[:taken_actions]
    taken = taken.keys if taken

    if PostActionType.is_flag?(action_key)
      return false unless @user.has_trust_level?(:basic)

      if taken
        return false unless (taken & PostActionType.flag_types.values).empty?
      end
    else
      return false if taken && taken.include?(PostActionType.types[action_key])
    end

    case action_key
    when :like
      return false if post.user == @user
    when :vote then
      return false if opts[:voted_in_topic] && post.topic.has_meta_data_boolean?(:single_vote)
    end

    return true
  end

  def secure_category_ids
    @user ? @user.secure_category_ids : []
  end
end
