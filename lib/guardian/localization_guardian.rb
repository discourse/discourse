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

    return true if @user.in_any_groups?(SiteSetting.content_localization_allowed_groups_map)
    return false if !SiteSetting.content_localization_allow_author_localization

    post = post_or_post_id.is_a?(Post) ? post_or_post_id : Post.find_by(id: post_or_post_id)
    post&.user_id == @user.id
  end
end
