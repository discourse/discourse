# frozen_string_literal: true

# mixin for all guardian methods dealing with post permissions
module PostGuardian
  TOPIC_NOT_SUPPLIED = Object.new.freeze
  private_constant :TOPIC_NOT_SUPPLIED

  def unrestricted_link_posting?
    authenticated? && @user.in_any_groups?(SiteSetting.post_links_allowed_groups_map)
  end

  def link_posting_access
    if unrestricted_link_posting?
      "full"
    elsif SiteSetting.allowed_link_domains.present?
      "limited"
    else
      "none"
    end
  end

  def can_post_link?(host: nil)
    return false if host.blank?

    unrestricted_link_posting? || SiteSetting.allowed_link_domains.split("|").include?(host)
  end

  # Can the user act on the post in a particular way.
  #  taken_actions = the list of actions the user has already taken
  def post_can_act?(post, action_key, opts: {}, can_see_post: nil)
    return false if action_key == :illegal && SiteSetting.dsa_reporting_enabled
    return false if !(can_see_post.nil? && can_see_post?(post)) && !can_see_post

    # no warnings except for staff
    if action_key == :notify_user && (post.user.blank? || (!is_staff? && opts[:is_warning]))
      return false
    end

    taken = opts[:taken_actions].try(:keys).to_a
    post_action_type_view = opts[:post_action_type_view] || PostActionTypeView.new
    is_flag =
      if opts[:notify_flag_types] && opts[:additional_message_types]
        opts[:notify_flag_types][action_key] || opts[:additional_message_types][action_key]
      else
        post_action_type_view.notify_flag_types[action_key] ||
          post_action_type_view.additional_message_types[action_key]
      end
    already_taken_this_action =
      taken.any? && taken.include?(post_action_type_view.types[action_key])
    already_did_flagging =
      taken.any? && (taken & post_action_type_view.notify_flag_types.values).any?

    result =
      if authenticated? && post
        topic = post_topic_including_deleted(post)
        # Allow anonymous users to like if feature is enabled and short-circuit otherwise
        if @user.anonymous?
          return SiteSetting.allow_likes_in_anonymous_mode? && (action_key == :like)
        end

        # Silenced users can't flag, except to report illegal content
        if is_flag && @user.silenced? &&
             !(action_key == :illegal && SiteSetting.allow_all_users_to_flag_illegal_content)
          return false
        end

        # Silenced users can't like
        return false if action_key == :like && @user.silenced?

        # Hidden posts can't be flagged
        return false if is_flag && post.hidden?

        # post made by staff, but we don't allow staff flags
        return false if is_flag && !SiteSetting.allow_flagging_staff? && post&.user&.staff?

        if is_flag && post_action_type_view.disabled_flag_types.keys.include?(action_key)
          return false
        end

        if action_key == :notify_user &&
             !@user.in_any_groups?(SiteSetting.personal_message_enabled_groups_map)
          # The modifier below is used to add additional permissions for notifying users.
          # In core the only method of notifying a user is personal messages so we check if the
          # user can PM. Plugins can extend the behavior of how users are notifier via `notify_user`
          # post action, and this allows extension for that use case.
          can_notify = false
          can_notify =
            DiscoursePluginRegistry.apply_modifier(
              :post_guardian_can_notify_user,
              can_notify,
              self,
              post,
            )
          return can_notify
        end

        # we allow flagging for trust level 1 and higher
        # always allowed for private messages
        (
          is_flag && not(already_did_flagging) &&
            (
              @user.in_any_groups?(SiteSetting.flag_post_allowed_groups_map) ||
                topic&.private_message?
            )
        ) || (action_key == :illegal && SiteSetting.allow_all_users_to_flag_illegal_content) ||
          # not a flagging action, and haven't done it already
          not(is_flag || already_taken_this_action) &&
            # nothing except flagging on archived topics
            not(topic&.archived?) &&
            # nothing except flagging on deleted posts
            not(post.trashed?) &&
            # don't like your own stuff
            not(action_key == :like && (post.user.blank? || is_my_own?(post)))
      end

    !!result
  end

  def can_lock_post?(post)
    can_see_post?(post) && is_staff?
  end

  # Can we see who acted on a post in a particular way?
  def can_see_post_actors?(topic, post_action_type_id)
    return true if is_admin?
    return false unless topic

    post_action_type_view = PostActionTypeView.new
    type_symbol = post_action_type_view.types[post_action_type_id]

    return false if type_symbol == :bookmark
    return false if type_symbol == :notify_user && !is_moderator?

    return can_see_flags?(topic) if post_action_type_view.is_flag?(type_symbol)

    true
  end

  def can_delete_all_posts?(user)
    is_staff? && user && !user.admin? && (!user.moderator? || is_admin?) &&
      (
        is_admin? ||
          (
            (
              user.first_post_created_at.nil? ||
                user.first_post_created_at >= SiteSetting.delete_user_max_post_age.days.ago
            ) && user.post_count <= SiteSetting.delete_all_posts_max.to_i
          )
      )
  end

  def can_create_post?(topic)
    return can_create_post_in_topic?(topic) if !topic

    key = topic_memoize_key(topic)
    @can_create_post ||= {}

    @can_create_post.fetch(key) { @can_create_post[key] = can_create_post_in_topic?(topic) }
  end

  def can_edit_post?(post)
    return false if Discourse.static_doc_topic_ids.include?(post.topic_id) && !is_admin?

    return true if is_admin?

    post.topic ||= Topic.with_deleted.find_by(id: post.topic_id) if post.topic_id

    # Must be staff to edit a locked post
    return false if post.locked? && !is_staff?

    # Staff in edit groups skip visibility (e.g. deleted topics); non-staff must pass it
    if is_in_edit_post_groups?
      return can_create_post?(post.topic) if is_staff?
      return can_create_post?(post.topic) if can_see_post_topic?(post)
      return false
    end
    return false if !can_see_post_topic?(post)
    return can_create_post?(post.topic) if is_category_group_moderator?(post.topic&.category)

    return false if post.topic&.archived? || post.user_deleted || post.deleted_at

    # Editing a shared draft.
    if can_see_post?(post) && can_create_post?(post.topic) &&
         post.topic.category_id == SiteSetting.shared_drafts_category.to_i &&
         can_see_category?(post.topic.category) && can_see_shared_draft?
      return true
    end

    if post.wiki && @user.in_any_groups?(SiteSetting.edit_wiki_post_allowed_groups_map)
      return false if post.hidden? && is_my_own?(post) && !can_edit_hidden_post?(post)
      return can_create_post?(post.topic)
    end

    return false if !trusted_with_post_edits?

    if is_my_own?(post)
      return false if !is_staff? && !visible_post_types.include?(post.post_type)
      return false if @user.silenced?

      return can_edit_hidden_post?(post) if post.hidden?

      if post.is_first_post? && post.topic.category_allows_unlimited_owner_edits_on_first_post?
        return true
      end

      return !post.edit_time_limit_expired?(@user)
    end

    if post.is_category_description?
      return true if can_edit_category_description?(post.topic.category)
    end

    false
  end

  def is_in_edit_post_groups?
    user.in_any_groups?(SiteSetting.edit_all_post_groups_map)
  end

  def can_edit_hidden_post?(post)
    return false if post.nil?
    post.hidden_at.nil? ||
      post.hidden_at < SiteSetting.cooldown_minutes_after_hiding_posts.minutes.ago
  end

  def can_delete_post_or_topic?(post)
    if post.is_first_post?
      post.topic && can_delete_topic?(post.topic)
    else
      can_delete_post?(post)
    end
  end

  def can_delete_post?(post)
    return false if !can_see_post?(post)

    # Can't delete the first post
    return false if post.is_first_post?

    topic = post_topic_including_deleted(post)
    return true if is_category_group_moderator?(topic&.category)

    return true if can_delete_all_posts_and_topics?

    # Can't delete posts in archived topics unless you are staff
    return false if topic&.archived?

    # You can delete your own posts
    if is_my_own?(post)
      if SiteSetting.max_post_deletions_per_minute < 1 || SiteSetting.max_post_deletions_per_day < 1
        return false
      end
      return true if !post.user_deleted?
    end

    false
  end

  def can_permanently_delete_post?(post)
    return false if !SiteSetting.can_permanently_delete
    return false if !post
    return false if post.is_first_post?
    return false if !is_admin? || !can_edit_post?(post)
    return false if !post.deleted_at
    if post.deleted_by_id == @user.id && post.deleted_at >= Post::PERMANENT_DELETE_TIMER.ago
      return false
    end
    true
  end

  def can_recover_post?(post)
    return false unless post

    # PERF, vast majority of the time topic will not be deleted
    topic = post.topic || Topic.with_deleted.find(post.topic_id) if post.topic_id
    return true if can_moderate_topic?(topic) && !!post.deleted_at

    if is_my_own?(post)
      if SiteSetting.max_post_deletions_per_minute < 1 || SiteSetting.max_post_deletions_per_day < 1
        return false
      end
      return true if post.user_deleted && !post.deleted_at
    end

    false
  end

  def can_delete_post_action?(post_action)
    return false unless is_my_own?(post_action) && !post_action.is_private_message?

    ok_to_delete =
      post_action.created_at > SiteSetting.post_undo_action_window_mins.minutes.ago &&
        !post_action.post&.topic&.archived?

    # NOTE: This looks strange...but we are checking if someone is posting anonymously
    # as a AnonymousUser model, _not_ as Guardian::AnonymousUser which is a different thing
    # used when !authenticated?
    if authenticated? && is_anonymous?
      return(
        ok_to_delete && SiteSetting.allow_likes_in_anonymous_mode? && post_action.is_like? &&
          is_my_own?(post_action)
      )
    end

    ok_to_delete
  end

  def can_receive_post_notifications?(post)
    return false if !authenticated?

    if is_admin? && SiteSetting.suppress_secured_categories_from_admin
      topic = post_topic_including_deleted(post)
      return false if !topic
      if topic.private_message?
        return can_see_post_topic?(post)
      elsif topic.category&.read_restricted
        return secure_category_ids.include?(topic.category_id)
      end
    end
    can_see_post?(post)
  end

  def can_see_post?(post)
    return false if post.blank?
    return true if is_admin?
    topic = post_topic_including_deleted(post)
    return false unless can_see_post_topic?(post)
    return false if visible_post_types.exclude?(post.post_type)
    return true if is_moderator? || is_category_group_moderator?(topic&.category)
    if (!post.trashed? || can_see_deleted_post?(post)) &&
         (!post.hidden? || can_see_hidden_post?(post))
      return true
    end
    false
  end

  # Adds visibility predicates without joining or removing the caller's conditions.
  # A supplied persisted, unchanged topic is authorized once and constrains topic_id.
  def filter_visible_posts(scope, topic: TOPIC_NOT_SUPPLIED)
    if !topic.equal?(TOPIC_NOT_SUPPLIED)
      return scope.none if !topic || !topic.persisted? || topic.has_changes_to_save?

      scope = scope.where("posts.topic_id = ?", topic.id)
      return scope if is_admin?
      return scope.none if !can_see_post_topic_record?(topic)

      scope = scope.where("posts.post_type IN (?)", visible_post_types)
      return scope if is_moderator? || is_category_group_moderator?(topic.category)

      return scope.where(visible_post_state_sql)
    end

    return scope if is_admin?

    scope = scope.where("posts.post_type IN (?)", visible_post_types)
    topics = visible_topic_scope(Topic.unscoped.where("topics.id = posts.topic_id"))

    if !is_moderator?
      post_rules = visible_post_state_sql
      if moderated_category_ids.present?
        moderated_topics =
          Topic
            .unscoped
            .where(category_id: moderated_category_ids)
            .where("topics.id = posts.topic_id")
        scope = scope.where("(#{post_rules}) OR EXISTS (#{moderated_topics.select(1).to_sql})")
      else
        scope = scope.where(post_rules)
      end
    end

    scope.where("EXISTS (#{topics.select(1).to_sql})")
  end

  def reviewable_post_scope
    return Post.with_deleted if is_admin?
    return Post.none if !is_staff? && !category_group_moderation_allowed?

    topics = visible_topic_scope(Topic.with_deleted.where("topics.id = posts.topic_id"))
    topics = topics.where(category_id: category_group_moderator_scope.select(:id)) if !is_staff?

    Post.with_deleted.with_visible_post_types(self).where("EXISTS (#{topics.select(1).to_sql})")
  end

  def can_review_post?(post)
    return false if post.blank?
    return true if is_admin?

    reviewable_post_scope.exists?(id: post.id)
  end

  def can_see_deleted_post?(post)
    return false if !post.trashed?
    return false if @user.anonymous?
    return true if is_staff?
    post.deleted_by_id == @user.id && @user.has_trust_level?(TrustLevel[4])
  end

  def filter_hidden_posts(records, category: nil, category_id_column: "topics.category_id")
    return records if can_see_all_hidden_posts?(category)
    return records.where(posts: { hidden: false }) if anonymous?

    conditions = ["posts.hidden = false", "posts.user_id = :user_id"]
    params = { user_id: user.id }

    if category.nil? && category_group_moderation_allowed?
      conditions << "#{category_id_column} IN (:moderated_category_ids)"
      params[:moderated_category_ids] = category_group_moderator_scope.select(:id)
    end

    records.where(conditions.join(" OR "), params)
  end

  def can_see_all_hidden_posts?(category = nil)
    # TODO (martin) Remove this when granular_anonymous_and_logged_in_groups_permissions is
    # permanent, as the check is covered inside guardian.in_any_groups? for anon
    return false if anonymous? && !SiteSetting.granular_anonymous_and_logged_in_groups_permissions

    in_any_groups?(SiteSetting.hidden_post_visible_groups_map) ||
      is_category_group_moderator?(category)
  end

  def can_see_hidden_post?(post)
    return true if can_see_all_hidden_posts?
    # TODO (martin) Remove this when granular_anonymous_and_logged_in_groups_permissions is
    # permanent, as the check is covered inside guardian.in_any_groups? for anon
    return false if anonymous? && !SiteSetting.granular_anonymous_and_logged_in_groups_permissions
    is_my_own?(post)
  end

  def can_view_edit_history?(post)
    return false unless post

    if !post.hidden
      return true if post.wiki || SiteSetting.edit_history_visible_to_public
    end

    return false if !authenticated?
    return false if !can_see_post?(post)

    is_staff? || is_my_own?(post) ||
      is_category_group_moderator?(post_topic_including_deleted(post)&.category)
  end

  def can_change_post_owner?
    return true if is_admin?
    return true if SiteSetting.moderators_change_post_ownership && is_staff?
    return true if @user.in_any_groups?(SiteSetting.change_post_ownership_allowed_groups_map)
    false
  end

  def can_change_post_timestamps?
    is_staff?
  end

  def can_wiki?(post)
    return false unless authenticated?
    return true if is_staff? || @user.has_trust_level?(TrustLevel[4])

    if @user.in_any_groups?(SiteSetting.self_wiki_allowed_groups_map) && is_my_own?(post)
      return false if post.hidden?
      return !post.edit_time_limit_expired?(@user)
    end

    false
  end

  def can_change_post_type?
    is_staff?
  end

  def can_rebake?
    is_staff? || @user.has_trust_level?(TrustLevel[4])
  end

  def can_see_deleted_posts?(category = nil)
    is_category_group_moderator?(category) || can_delete_all_posts_and_topics?
  end

  def can_see_deleted_posts_for_user?
    is_staff?
  end

  def can_view_raw_emails?
    @user.in_any_groups?(SiteSetting.view_raw_email_allowed_groups_map)
  end

  def can_view_raw_email?(post)
    post && can_view_raw_emails?
  end

  def can_unhide?(post)
    post.try(:hidden) && is_staff?
  end

  def can_skip_bump?
    is_staff? || @user.has_trust_level?(TrustLevel[4])
  end

  def trusted_with_post_edits?
    @user.in_any_groups?(SiteSetting.edit_post_allowed_groups_map)
  end

  private

  def visible_post_types
    @visible_post_types ||= Topic.visible_post_types(@user)
  end

  def can_create_post_in_topic?(topic)
    if !SiteSetting.enable_system_message_replies? && topic&.subtype == "system_message"
      return false
    end

    is_pm = !!topic&.private_message?
    return false if is_pm && !can_see_topic?(topic)
    return false if !is_pm && SpamRule::AutoSilence.prevent_posting?(@user)

    !topic || !topic.category ||
      Category.post_create_allowed(self).where(id: topic.category_id).exists?
  end

  def topic_memoize_key(topic)
    # Milliseconds precision on Topic#updated_at so that we don't use memoized results after topic has been updated.
    "#{topic.id}-#{(topic.updated_at.to_f * 1000).to_i}"
  end

  def visible_post_state_sql
    # String predicates survive Trashable#with_deleted's attribute-based unscope.
    deleted = "posts.deleted_at IS NULL"
    if authenticated? && !user.anonymous? && user.has_trust_level?(TrustLevel[4])
      deleted = Post.sanitize_sql_array(["(#{deleted} OR posts.deleted_by_id = ?)", user.id])
    end

    return deleted if can_see_all_hidden_posts?

    hidden = "posts.hidden = FALSE"
    if authenticated?
      hidden = Post.sanitize_sql_array(["(#{hidden} OR posts.user_id = ?)", user.id])
    end

    "#{deleted} AND #{hidden}"
  end

  def post_topic_including_deleted(post)
    association = post.association(:topic)
    return association.target if association.target && !association.stale_target?

    @post_topics_including_deleted ||= {}
    @post_topics_including_deleted.fetch(post.topic_id) do
      @post_topics_including_deleted[post.topic_id] = Topic.with_deleted.find_by(id: post.topic_id)
    end
  end

  def can_see_post_topic?(post)
    topic = post_topic_including_deleted(post)
    return false if !topic

    can_see_post_topic_record?(topic)
  end

  def can_see_post_topic_record?(topic)
    return can_see_topic?(topic) if !topic.persisted? || topic.has_changes_to_save?

    key = topic_memoize_key(topic)
    @can_see_post_topic ||= {}

    @can_see_post_topic.fetch(key) { @can_see_post_topic[key] = can_see_topic?(topic) }
  end
end
