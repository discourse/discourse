# frozen_string_literal: true

#mixin for all guardian methods dealing with topic permissions
module TopicGuardian

  def can_remove_allowed_users?(topic, target_user = nil)
    is_staff? ||
    (topic.user == @user && @user.has_trust_level?(TrustLevel[2])) ||
    (
      topic.allowed_users.count > 1 &&
      topic.user != target_user &&
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
    return is_admin? if SiteSetting.shared_drafts_min_trust_level.to_s == 'admin'
    return is_staff? if SiteSetting.shared_drafts_min_trust_level.to_s == 'staff'

    @user.has_trust_level?(SiteSetting.shared_drafts_min_trust_level.to_i)
  end

  def can_create_whisper?
    is_staff? && SiteSetting.enable_whispers?
  end

  def can_see_whispers?(_topic)
    is_staff?
  end

  def can_publish_topic?(topic, category)
    can_see_shared_draft? && can_see?(topic) && can_create_topic_on_category?(category)
  end

  # Creating Methods
  def can_create_topic?(parent)
    is_staff? ||
    (user &&
      user.trust_level >= SiteSetting.min_trust_to_create_topic.to_i &&
      can_create_post?(parent) &&
      Category.topic_create_allowed(self).limit(1).count == 1)
  end

  def can_create_topic_on_category?(category)
    # allow for category to be a number as well
    category_id = Category === category ? category.id : category

    can_create_topic?(nil) &&
    (!category || Category.topic_create_allowed(self).where(id: category_id).count == 1)
  end

  def can_move_topic_to_category?(category)
    category = Category === category ? category : Category.find(category || SiteSetting.uncategorized_category_id)

    is_staff? || (can_create_topic_on_category?(category) && !category.require_topic_approval?)
  end

  def can_create_post_on_topic?(topic)
    # No users can create posts on deleted topics
    return false if topic.blank?
    return false if topic.trashed?
    return true if is_admin?

    trusted = (authenticated? && user.has_trust_level?(TrustLevel[4])) || is_moderator? || can_perform_action_available_to_group_moderators?(topic)

    (!(topic.closed? || topic.archived?) || trusted) && can_create_post?(topic)
  end

  # Editing Method
  def can_edit_topic?(topic)
    return false if Discourse.static_doc_topic_ids.include?(topic.id) && !is_admin?
    return false unless can_see?(topic)
    return false if topic.first_post&.locked? && !is_staff?

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
      return false if !can_create_topic_on_category?(topic.category)
    end

    # Editing a shared draft.
    return true if (
      !topic.archived &&
      !topic.private_message? &&
      topic.category_id == SiteSetting.shared_drafts_category.to_i &&
      can_see_category?(topic.category) &&
      can_see_shared_draft? &&
      can_create_post?(topic)
    )

    # TL4 users can edit archived topics, but can not edit private messages
    return true if (
      SiteSetting.trusted_users_can_edit_others? &&
      topic.archived &&
      !topic.private_message? &&
      user.has_trust_level?(TrustLevel[4]) &&
      can_create_post?(topic)
    )

    # TL3 users can not edit archived topics and private messages
    return true if (
      SiteSetting.trusted_users_can_edit_others? &&
      !topic.archived &&
      !topic.private_message? &&
      user.has_trust_level?(TrustLevel[3]) &&
      can_create_post?(topic)
    )

    return false if topic.archived
    is_my_own?(topic) &&
      !topic.edit_time_limit_expired?(user) &&
      !Post.where(topic_id: topic.id, post_number: 1).where.not(locked_by_id: nil).exists?
  end

  def can_recover_topic?(topic)
    if is_staff? || (topic&.category && is_category_group_moderator?(topic.category))
      !!(topic && topic.deleted_at)
    else
      topic && can_recover_post?(topic.ordered_posts.first)
    end
  end

  def can_delete_topic?(topic)
    !topic.trashed? &&
    (is_staff? || (is_my_own?(topic) && topic.posts_count <= 1 && topic.created_at && topic.created_at > 24.hours.ago) || is_category_group_moderator?(topic.category)) &&
    !topic.is_category_topic? &&
    !Discourse.static_doc_topic_ids.include?(topic.id)
  end

  def can_toggle_topic_visibility?(topic)
    can_moderate?(topic) || can_perform_action_available_to_group_moderators?(topic)
  end

  def can_convert_topic?(topic)
    return false unless SiteSetting.enable_personal_messages?
    return false if topic.blank?
    return false if topic.trashed?
    return false if topic.is_category_topic?
    return true if is_admin?
    is_moderator? && can_create_post?(topic)
  end

  def can_reply_as_new_topic?(topic)
    authenticated? && topic && @user.has_trust_level?(TrustLevel[1])
  end

  def can_see_deleted_topics?(category)
    is_staff? || is_category_group_moderator?(category)
  end

  def can_see_topic?(topic, hide_deleted = true)
    return false unless topic
    return true if is_admin?
    return false if hide_deleted && topic.deleted_at && !can_see_deleted_topics?(topic.category)

    if topic.private_message?
      return authenticated? && topic.all_allowed_users.where(id: @user.id).exists?
    end

    return false if topic.shared_draft && !can_see_shared_draft?

    category = topic.category
    can_see_category?(category) &&
      (!category.read_restricted || !is_staged? || secure_category_ids.include?(category.id) || topic.user == user)
  end

  def can_get_access_to_topic?(topic)
    topic&.access_topic_via_group.present? && authenticated?
  end

  def filter_allowed_categories(records)
    unless is_admin?
      records = allowed_category_ids.size == 0 ?
        records.where('topics.category_id IS NULL') :
        records.where('topics.category_id IS NULL or topics.category_id IN (?)', allowed_category_ids)
      records = records.references(:categories)
    end
    records
  end

  def can_edit_featured_link?(category_id)
    return false unless SiteSetting.topic_featured_link_enabled
    Category.where(id: category_id || SiteSetting.uncategorized_category_id, topic_featured_link_allowed: true).exists?
  end

  def can_update_bumped_at?
    is_staff? || @user.has_trust_level?(TrustLevel[4])
  end

  def can_banner_topic?(topic)
    topic && authenticated? && !topic.private_message? && is_staff?
  end

  def can_edit_tags?(topic)
    return false unless can_tag_topics?
    return false if topic.private_message? && !can_tag_pms?
    return true if can_edit_topic?(topic)

    if topic&.first_post&.wiki && (@user.trust_level >= SiteSetting.min_trust_to_edit_wiki_post.to_i)
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
  alias :can_archive_topic? :can_perform_action_available_to_group_moderators?
  alias :can_close_topic? :can_perform_action_available_to_group_moderators?
  alias :can_open_topic? :can_perform_action_available_to_group_moderators?
  alias :can_split_merge_topic? :can_perform_action_available_to_group_moderators?
  alias :can_edit_staff_notes? :can_perform_action_available_to_group_moderators?
  alias :can_pin_unpin_topic? :can_perform_action_available_to_group_moderators?

  def can_move_posts?(topic)
    return false if is_silenced?
    can_perform_action_available_to_group_moderators?(topic)
  end

  def affected_by_slow_mode?(topic)
    topic&.slow_mode_seconds.to_i > 0 && @user.human? && !is_staff?
  end

end
