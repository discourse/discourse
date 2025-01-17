# frozen_string_literal: true

#mixin for all guardian methods dealing with topic permissions
module TopicGuardian
  def can_remove_allowed_users?(topic, target_user = nil)
    is_staff? || (topic.user == @user && @user.has_trust_level?(TrustLevel[2])) ||
      (
        topic.allowed_users.count > 1 && topic.user != target_user &&
          !!(target_user && user == target_user)
      )
  end

  def can_review_topic?(topic)
    return false if anonymous? || topic.nil?
    return true if is_staff?

    is_category_group_moderator?(topic.category)
  end

  def can_moderate_topic?(topic)
    return false if anonymous? || topic.nil?
    return true if is_staff?

    can_perform_action_available_to_group_moderators?(topic)
  end

  def can_create_shared_draft?
    SiteSetting.shared_drafts_enabled? && can_see_shared_draft?
  end

  def can_see_shared_draft?
    @user.in_any_groups?(SiteSetting.shared_drafts_allowed_groups_map)
  end

  def can_create_whisper?
    @user.whisperer?
  end

  def can_see_whispers?(_topic = nil)
    @user.whisperer?
  end

  def can_publish_topic?(topic, category)
    can_see_shared_draft? && can_see?(topic) && can_create_topic_on_category?(category)
  end

  # Creating Methods
  def can_create_topic?(parent)
    is_staff? ||
      (
        user && user.in_any_groups?(SiteSetting.create_topic_allowed_groups_map) &&
          can_create_post?(parent) && Category.topic_create_allowed(self).any?
      )
  end

  def can_create_topic_on_category?(category)
    # allow for category to be a number as well
    category_id = Category === category ? category.id : category

    can_create_topic?(nil) &&
      (!category || Category.topic_create_allowed(self).where(id: category_id).count == 1)
  end

  def can_move_topic_to_category?(category)
    category =
      (
        if Category === category
          category
        else
          Category.find(category || SiteSetting.uncategorized_category_id)
        end
      )

    is_staff? || (can_create_topic_on_category?(category) && !category.require_topic_approval?)
  end

  def can_create_post_on_topic?(topic)
    # No users can create posts on deleted topics
    return false if topic.blank?
    return false if topic.trashed?
    return true if is_admin?

    trusted =
      (authenticated? && user.has_trust_level?(TrustLevel[4])) || is_moderator? ||
        can_perform_action_available_to_group_moderators?(topic)

    (!(topic.closed? || topic.archived?) || trusted) && can_create_post?(topic)
  end

  # Editing Method
  def can_edit_topic?(topic)
    return false if Discourse.static_doc_topic_ids.include?(topic.id) && !is_admin?
    return false if cannot_see?(topic)

    first_post = topic.first_post

    return false if first_post&.locked? && !is_staff?

    return true if is_admin?
    return true if is_moderator? && can_create_post?(topic)
    return true if is_category_group_moderator?(topic.category)

    # can't edit topics in secured categories where you don't have permission to create topics
    # except for a tiny edge case where the topic is uncategorized and you are trying
    # to fix it but uncategorized is disabled
    if (
         SiteSetting.allow_uncategorized_topics ||
           topic.category_id != SiteSetting.uncategorized_category_id
       )
      return false if cannot_create_topic_on_category?(topic.category)
    end

    # Editing a shared draft.
    if (
         !topic.archived && !topic.private_message? &&
           topic.category_id == SiteSetting.shared_drafts_category.to_i &&
           can_see_category?(topic.category) && can_see_shared_draft? && can_create_post?(topic)
       )
      return true
    end

    if (
         is_in_edit_post_groups? && topic.archived && !topic.private_message? &&
           can_create_post?(topic)
       )
      return true
    end

    if (
         is_in_edit_topic_groups? && !topic.archived && !topic.private_message? &&
           can_create_post?(topic)
       )
      return true
    end

    return false if topic.archived

    is_my_own?(topic) && !topic.edit_time_limit_expired?(user) && !first_post&.locked? &&
      (!first_post&.hidden? || can_edit_hidden_post?(first_post))
  end

  def is_in_edit_topic_groups?
    SiteSetting.edit_all_topic_groups.present? &&
      user.in_any_groups?(SiteSetting.edit_all_topic_groups.to_s.split("|").map(&:to_i))
  end

  def can_recover_topic?(topic)
    if is_staff? || (topic&.category && is_category_group_moderator?(topic.category)) ||
         user&.in_any_groups?(SiteSetting.delete_all_posts_and_topics_allowed_groups_map)
      !!(topic && topic.deleted_at)
    else
      topic && can_recover_post?(topic.ordered_posts.first)
    end
  end

  def can_delete_topic?(topic)
    !topic.trashed? &&
      (
        is_staff? ||
          (
            is_my_own?(topic) && topic.posts_count <= 1 && topic.created_at &&
              topic.created_at > 24.hours.ago
          ) || is_category_group_moderator?(topic.category) ||
          user&.in_any_groups?(SiteSetting.delete_all_posts_and_topics_allowed_groups_map)
      ) && !topic.is_category_topic? && !Discourse.static_doc_topic_ids.include?(topic.id)
  end

  def can_permanently_delete_topic?(topic)
    return false if !SiteSetting.can_permanently_delete
    return false if !topic

    # Ensure that all posts (including small actions) are at least soft
    # deleted.
    return false if topic.posts_count > 0

    # All other posts that were deleted still must be permanently deleted
    # before the topic can be deleted with the exception of small action
    # posts that will be deleted right before the topic is.
    all_posts_count =
      Post
        .with_deleted
        .where(topic_id: topic.id)
        .where(
          post_type: [Post.types[:regular], Post.types[:moderator_action], Post.types[:whisper]],
        )
        .count
    return false if all_posts_count > 1

    return false if !is_admin? || cannot_see_topic?(topic)
    return false if !topic.deleted_at
    if topic.deleted_by_id == @user.id && topic.deleted_at >= Post::PERMANENT_DELETE_TIMER.ago
      return false
    end
    true
  end

  def can_toggle_topic_visibility?(topic)
    can_moderate?(topic) || can_perform_action_available_to_group_moderators?(topic)
  end

  def can_create_unlisted_topic?(topic, has_topic_embed = false)
    can_toggle_topic_visibility?(topic) || has_topic_embed
  end

  def can_convert_topic?(topic)
    return false if topic.blank?
    return false if topic.trashed?
    return false if topic.is_category_topic?
    return true if is_admin?
    return false if !@user.in_any_groups?(SiteSetting.personal_message_enabled_groups_map)
    is_moderator? && can_create_post?(topic)
  end

  def can_reply_as_new_topic?(topic)
    authenticated? && topic && @user.has_trust_level?(TrustLevel[1])
  end

  def can_see_deleted_topics?(category)
    is_staff? || is_category_group_moderator?(category) ||
      user&.in_any_groups?(SiteSetting.delete_all_posts_and_topics_allowed_groups_map)
  end

  # Accepts an array of `Topic#id` and returns an array of `Topic#id` which the user can see.
  def can_see_topic_ids(topic_ids: [], hide_deleted: true)
    topic_ids = topic_ids.compact

    return topic_ids if is_admin? && !SiteSetting.suppress_secured_categories_from_admin
    return [] if topic_ids.blank?

    default_scope = Topic.unscoped.where(id: topic_ids)

    # When `hide_deleted` is `true`, hide deleted topics if user is not staff or category moderator
    if hide_deleted && !is_staff?
      if category_group_moderation_allowed?
        default_scope = default_scope.where(<<~SQL)
          (
            deleted_at IS NULL OR
            (
              deleted_at IS NOT NULL
              AND topics.category_id IN (#{category_group_moderator_scope.select(:id).to_sql})
            )
          )
        SQL
      else
        default_scope = default_scope.where("deleted_at IS NULL")
      end
    end

    # Filter out topics with shared drafts if user cannot see shared drafts
    if cannot_see_shared_draft?
      default_scope =
        default_scope.left_outer_joins(:shared_draft).where("shared_drafts.id IS NULL")
    end

    all_topics_scope =
      if authenticated?
        Topic.unscoped.merge(
          secured_regular_topic_scope(default_scope, topic_ids: topic_ids).or(
            private_message_topic_scope(default_scope),
          ),
        )
      else
        Topic.unscoped.merge(secured_regular_topic_scope(default_scope, topic_ids: topic_ids))
      end

    all_topics_scope.pluck(:id)
  end

  def can_see_topic?(topic, hide_deleted = true)
    return false unless topic
    return true if is_admin? && !SiteSetting.suppress_secured_categories_from_admin
    return false if hide_deleted && topic.deleted_at && cannot_see_deleted_topics?(topic.category)

    if topic.private_message?
      return authenticated? && topic.all_allowed_users.where(id: @user.id).exists?
    end

    return false if topic.shared_draft && cannot_see_shared_draft?

    category = topic.category
    can_see_category?(category) &&
      (
        !category.read_restricted || !is_staged? || secure_category_ids.include?(category.id) ||
          topic.user == user
      )
  end

  def can_see_unlisted_topics?
    is_staff? || @user.has_trust_level?(TrustLevel[4])
  end

  def can_get_access_to_topic?(topic)
    topic&.access_topic_via_group.present? && authenticated?
  end

  def filter_allowed_categories(records, category_id_column: "topics.category_id")
    return records if is_admin? && !SiteSetting.suppress_secured_categories_from_admin

    records =
      if allowed_category_ids.size == 0
        records.where("#{category_id_column} IS NULL")
      else
        records.where(
          "#{category_id_column} IS NULL or #{category_id_column} IN (?)",
          allowed_category_ids,
        )
      end

    records.references(:categories)
  end

  def can_edit_featured_link?(category_id)
    return false unless SiteSetting.topic_featured_link_enabled
    return false if @user.trust_level == TrustLevel.levels[:newuser]
    Category.where(
      id: category_id || SiteSetting.uncategorized_category_id,
      topic_featured_link_allowed: true,
    ).exists?
  end

  def can_update_bumped_at?
    is_staff? || @user.has_trust_level?(TrustLevel[4])
  end

  def can_banner_topic?(topic)
    topic && authenticated? && !topic.private_message? && is_staff?
  end

  def can_edit_tags?(topic)
    return false if cannot_tag_topics?
    return false if topic.private_message? && cannot_tag_pms?
    return true if can_edit_topic?(topic)

    if topic&.first_post&.wiki &&
         @user.in_any_groups?(SiteSetting.edit_wiki_post_allowed_groups_map)
      return can_create_post?(topic)
    end

    false
  end

  def can_perform_action_available_to_group_moderators?(topic)
    return false if anonymous? || topic.nil?
    return true if is_staff?
    return true if @user.has_trust_level?(TrustLevel[4])

    is_category_group_moderator?(topic.category)
  end
  alias can_archive_topic? can_perform_action_available_to_group_moderators?
  alias can_close_topic? can_perform_action_available_to_group_moderators?
  alias can_open_topic? can_perform_action_available_to_group_moderators?
  alias can_split_merge_topic? can_perform_action_available_to_group_moderators?
  alias can_edit_staff_notes? can_perform_action_available_to_group_moderators?
  alias can_pin_unpin_topic? can_perform_action_available_to_group_moderators?

  def can_move_posts?(topic)
    return false if is_silenced?
    return false if cannot_perform_action_available_to_group_moderators?(topic)
    return false if topic.archetype == "private_message" && !is_staff?
    true
  end

  def affected_by_slow_mode?(topic)
    topic&.slow_mode_seconds.to_i > 0 && @user.human? && !is_staff?
  end

  private

  def private_message_topic_scope(scope)
    pm_scope = scope.private_messages_for_user(user)

    pm_scope = pm_scope.or(scope.where(<<~SQL)) if is_moderator?
        topics.subtype = '#{TopicSubtype.moderator_warning}'
        OR topics.id IN (#{Topic.has_flag_scope.select(:topic_id).to_sql})
      SQL

    pm_scope
  end

  def secured_regular_topic_scope(scope, topic_ids:)
    secured_scope = Topic.unscoped.secured(self)

    # Staged users are allowed to see their own topics in read restricted categories when Category#email_in and
    # Category#email_in_allow_strangers has been configured.
    if is_staged?
      sql = <<~SQL
      topics.id IN (
        SELECT
          topics.id
        FROM topics
        INNER JOIN categories ON categories.id = topics.category_id
        WHERE categories.read_restricted
        AND categories.email_in IS NOT NULL
        AND categories.email_in_allow_strangers
        AND topics.user_id = :user_id
        AND topics.id IN (:topic_ids)
      )
      SQL

      secured_scope =
        secured_scope.or(Topic.unscoped.where(sql, user_id: user.id, topic_ids: topic_ids))
    end

    scope.listable_topics.merge(secured_scope)
  end
end
