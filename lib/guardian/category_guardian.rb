# frozen_string_literal: true

#mixin for all guardian methods dealing with category permisions
module CategoryGuardian

  # Creating Method
  def can_create_category?(parent = nil)
    is_admin? ||
    (
      SiteSetting.moderators_create_categories &&
      is_moderator?
    )
  end

  # Editing Method
  def can_edit_category?(category)
    is_admin? ||
    (
      SiteSetting.moderators_create_categories &&
      is_moderator? &&
      can_see_category?(category)
    )
  end

  def can_delete_category?(category)
    can_edit_category?(category) &&
    category.topic_count <= 0 &&
    !category.uncategorized? &&
    !category.has_children?
  end

  def cannot_delete_category_reason(category)
    return I18n.t('category.cannot_delete.uncategorized') if category.uncategorized?
    return I18n.t('category.cannot_delete.has_subcategories') if category.has_children?

    if category.topic_count != 0
      oldest_topic = category.topics.where.not(id: category.topic_id).order('created_at ASC').limit(1).first
      if oldest_topic
        return I18n.t('category.cannot_delete.topic_exists', count: category.topic_count, topic_link: "<a href=\"#{oldest_topic.url}\">#{CGI.escapeHTML(oldest_topic.title)}</a>")
      else
        # This is a weird case, probably indicating a bug.
        return I18n.t('category.cannot_delete.topic_exists_no_oldest', count: category.topic_count)
      end
    end

    nil
  end

  def can_see_category?(category)
    return false unless category
    return true if is_admin?
    return true if !category.read_restricted
    return true if is_staged? && category.email_in.present? && category.email_in_allow_strangers
    secure_category_ids.include?(category.id)
  end

  def secure_category_ids
    @secure_category_ids ||= @user.secure_category_ids
  end

  # all allowed category ids
  def allowed_category_ids
    @allowed_category_ids ||=
      begin
        unrestricted = Category.where(read_restricted: false).pluck(:id)
        unrestricted.concat(secure_category_ids)
      end
  end

  def topic_create_allowed_category_ids
    @topic_create_allowed_category_ids ||= @user.topic_create_allowed_category_ids
  end

  def topic_featured_link_allowed_category_ids
    @topic_featured_link_allowed_category_ids = Category.where(topic_featured_link_allowed: true).pluck(:id)
  end
end
