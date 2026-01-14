# frozen_string_literal: true

module LocalizationGuardian
  # Users that pass this guard are allowed to localize all content site-wide
  def can_localize_content?
    return false if !SiteSetting.content_localization_enabled
    return false if anonymous?

    @user.in_any_groups?(SiteSetting.content_localization_allowed_groups_map)
  end

  def can_localize_post?(post_or_post_id)
    return false if !SiteSetting.content_localization_enabled
    return false if anonymous?

    post = post_or_post_id.is_a?(Post) ? post_or_post_id : Post.find_by(id: post_or_post_id)
    return false if !can_see_post?(post)

    return true if @user.in_any_groups?(SiteSetting.content_localization_allowed_groups_map)
    return false if !SiteSetting.content_localization_allow_author_localization

    post.user_id == @user.id
  end

  def can_localize_topic?(topic_or_topic_id)
    return false if !SiteSetting.content_localization_enabled
    return false if anonymous?

    topic =
      topic_or_topic_id.is_a?(Topic) ? topic_or_topic_id : Topic.find_by(id: topic_or_topic_id)
    return false if !can_see_topic?(topic)

    return true if @user.in_any_groups?(SiteSetting.content_localization_allowed_groups_map)
    return false if !SiteSetting.content_localization_allow_author_localization

    topic.user_id == @user.id
  end

  def can_localize_tag?(tag_or_tag_id)
    return false if !SiteSetting.content_localization_enabled
    return false if anonymous?
    return false if !@user.in_any_groups?(SiteSetting.content_localization_allowed_groups_map)

    tag = tag_or_tag_id.is_a?(Tag) ? tag_or_tag_id : Tag.find_by(id: tag_or_tag_id)
    !hidden_tag_names.include?(tag.name)
  end
end
