# frozen_string_literal: true

module LocalizationGuardian
  # Users that pass this guard are allowed to localize all content site-wide
  def can_localize_content?
    return false if !SiteSetting.content_localization_enabled
    return false if anonymous?

    @user.in_any_groups?(SiteSetting.content_localization_allowed_groups_map)
  end

  def can_localize_site_settings?
    SiteSetting.content_localization_enabled && is_admin?
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

  def can_localize_sidebar_section?(section_or_section_id)
    section = find_sidebar_section(section_or_section_id)

    can_localize_sidebar_section_title?(section)
  end

  def can_localize_sidebar_section_title?(section_or_section_id)
    return false if !SiteSetting.content_localization_enabled
    return false if anonymous?
    return false if !@user.admin?

    section = find_sidebar_section(section_or_section_id)
    section.present? && section.public? && section.custom_section?
  end

  def can_localize_sidebar_section_link?(section_or_section_id, link_value)
    return false if !SiteSetting.content_localization_enabled
    return false if anonymous?
    return false if !@user.admin?

    section = find_sidebar_section(section_or_section_id)
    return false if !section&.public?
    return true if section.custom_section?

    section.community_section? && !SidebarUrl.built_in_community_section_link_value?(link_value)
  end

  private

  def find_sidebar_section(section_or_section_id)
    section =
      (
        if section_or_section_id.is_a?(SidebarSection)
          section_or_section_id
        else
          SidebarSection.find_by(id: section_or_section_id)
        end
      )
  end
end
