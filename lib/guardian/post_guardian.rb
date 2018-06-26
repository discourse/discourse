#mixin for all guardian methods dealing with post permissions
module PostGuardian

  def unrestricted_link_posting?
    authenticated? && @user.has_trust_level?(TrustLevel[SiteSetting.min_trust_to_post_links])
  end

  def link_posting_access
    if unrestricted_link_posting?
      'full'
    elsif SiteSetting.whitelisted_link_domains.present?
      'limited'
    else
      'none'
    end
  end

  def can_post_link?(host: nil)
    return false if host.blank?

    unrestricted_link_posting? ||
      SiteSetting.whitelisted_link_domains.split('|').include?(host)
  end

  # Can the user act on the post in a particular way.
  #  taken_actions = the list of actions the user has already taken
  def post_can_act?(post, action_key, opts: {}, can_see_post: nil)
    return false unless (can_see_post.nil? && can_see_post?(post)) || can_see_post

    # no warnings except for staff
    return false if (action_key == :notify_user && !is_staff? && opts[:is_warning].present? && opts[:is_warning] == 'true')

    taken = opts[:taken_actions].try(:keys).to_a
    is_flag = PostActionType.notify_flag_types[action_key]
    already_taken_this_action = taken.any? && taken.include?(PostActionType.types[action_key])
    already_did_flagging      = taken.any? && (taken & PostActionType.notify_flag_types.values).any?

    result = if authenticated? && post && !@user.anonymous?
      # post made by staff, but we don't allow staff flags
      return false if is_flag &&
        (!SiteSetting.allow_flagging_staff?) &&
        post.user.staff?

      if [:notify_user, :notify_moderators].include?(action_key) &&
         (!SiteSetting.enable_personal_messages? ||
         !@user.has_trust_level?(SiteSetting.min_trust_to_send_messages))

        return false
      end

      # we allow flagging for trust level 1 and higher
      # always allowed for private messages
      (is_flag && not(already_did_flagging) && (@user.has_trust_level?(TrustLevel[SiteSetting.min_trust_to_flag_posts]) || post.topic.private_message?)) ||

      # not a flagging action, and haven't done it already
      not(is_flag || already_taken_this_action) &&

      # nothing except flagging on archived topics
      not(post.topic&.archived?) &&

      # nothing except flagging on deleted posts
      not(post.trashed?) &&

      # don't like your own stuff
      not(action_key == :like && is_my_own?(post))
    end

    !!result
  end

  def can_lock_post?(post)
    can_see_post?(post) && is_staff?
  end

  def can_defer_flags?(post)
    can_see_post?(post) && is_staff? && post
  end

  # Can we see who acted on a post in a particular way?
  def can_see_post_actors?(topic, post_action_type_id)
    return true if is_admin?
    return false unless topic

    type_symbol = PostActionType.types[post_action_type_id]

    return false if type_symbol == :bookmark
    return false if type_symbol == :notify_user && !is_moderator?

    return can_see_flags?(topic) if PostActionType.is_flag?(type_symbol)

    true
  end

  def can_delete_all_posts?(user)
    is_staff? &&
    user &&
    !user.admin? &&
    (user.first_post_created_at.nil? || user.first_post_created_at >= SiteSetting.delete_user_max_post_age.days.ago) &&
    user.post_count <= SiteSetting.delete_all_posts_max.to_i
  end

  # Creating Method
  def can_create_post?(parent)

    return false if !SiteSetting.enable_system_message_replies? && parent.try(:subtype) == "system_message"

    (!SpamRule::AutoSilence.silence?(@user) || (!!parent.try(:private_message?) && parent.allowed_users.include?(@user))) && (
      !parent ||
      !parent.category ||
      Category.post_create_allowed(self).where(id: parent.category.id).count == 1
    )
  end

  # Editing Method
  def can_edit_post?(post)
    if Discourse.static_doc_topic_ids.include?(post.topic_id) && !is_admin?
      return false
    end

    return true if is_admin?

    # Must be staff to edit a locked post
    return false if post.locked? && !is_staff?

    return can_create_post?(post.topic) if (
      is_staff? ||
      (
        SiteSetting.trusted_users_can_edit_others? &&
        @user.has_trust_level?(TrustLevel[4])
      )
    )

    if post.topic.archived? || post.user_deleted || post.deleted_at
      return false
    end

    if post.wiki && (@user.trust_level >= SiteSetting.min_trust_to_edit_wiki_post.to_i)
      return can_create_post?(post.topic)
    end

    if @user.trust_level < SiteSetting.min_trust_to_edit_post
      return false
    end

    if is_my_own?(post)
      if post.hidden?
        return false if post.hidden_at.present? &&
                        post.hidden_at >= SiteSetting.cooldown_minutes_after_hiding_posts.minutes.ago

        # If it's your own post and it's hidden, you can still edit it
        return true
      end

      return !post.edit_time_limit_expired?
    end

    false
  end

  # Deleting Methods
  def can_delete_post?(post)
    can_see_post?(post)

    # Can't delete the first post
    return false if post.is_first_post?

    # Can't delete posts in archived topics unless you are staff
    return false if !is_staff? && post.topic.archived?

    # You can delete your own posts
    return !post.user_deleted? if is_my_own?(post)

    is_staff?
  end

  # Recovery Method
  def can_recover_post?(post)
    if is_staff?
      post.deleted_at && post.user
    else
      is_my_own?(post) && post.user_deleted && !post.deleted_at
    end
  end

  def can_delete_post_action?(post_action)
    # You can only undo your own actions
    is_my_own?(post_action) && not(post_action.is_private_message?) &&

    # Make sure they want to delete it within the window
    post_action.created_at > SiteSetting.post_undo_action_window_mins.minutes.ago
  end

  def can_see_post?(post)
    return false if post.blank?
    return true if is_admin?
    return false unless can_see_topic?(post.topic)
    return false unless post.user == @user || Topic.visible_post_types(@user).include?(post.post_type)
    return false if !is_moderator? && post.deleted_at.present?

    true
  end

  def can_view_edit_history?(post)
    return false unless post

    if !post.hidden
      return true if post.wiki || SiteSetting.edit_history_visible_to_public
    end

    authenticated? &&
    (is_staff? || @user.has_trust_level?(TrustLevel[4]) || @user.id == post.user_id) &&
    can_see_post?(post)
  end

  def can_change_post_owner?
    is_admin?
  end

  def can_change_post_timestamps?
    is_admin?
  end

  def can_wiki?(post)
    return false unless authenticated?
    return true if is_staff? || @user.has_trust_level?(TrustLevel[4])

    if @user.has_trust_level?(SiteSetting.min_trust_to_allow_self_wiki) && is_my_own?(post)
      return false if post.hidden?
      return !post.edit_time_limit_expired?
    end

    false
  end

  def can_change_post_type?
    is_staff?
  end

  def can_rebake?
    is_staff? || @user.has_trust_level?(TrustLevel[4])
  end

  def can_see_flagged_posts?
    is_staff?
  end

  def can_see_deleted_posts?
    is_staff?
  end

  def can_view_raw_email?(post)
    post && (is_staff? || post.user_id == @user.id)
  end

  def can_unhide?(post)
    post.try(:hidden) && is_staff?
  end
end
