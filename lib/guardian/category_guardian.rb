#mixin for all guardian methods dealing with category permisions
module CategoryGuardian

  # Creating Method
  def can_create_category?(parent=nil)
    is_admin? ||
    (
      SiteSetting.allow_moderators_to_create_categories &&
      is_moderator?
    )
  end

  # Editing Method
  def can_edit_category?(category)
    is_admin? ||
    (
      SiteSetting.allow_moderators_to_create_categories &&
      is_moderator? &&
      can_see_category?(category)
    )
  end

  def can_delete_category?(category)
    can_edit_category?(category) &&
    category.topic_count == 0 &&
    !category.uncategorized? &&
    !category.has_children?
  end

  def can_see_category?(category)
    not(category.read_restricted) || secure_category_ids.include?(category.id)
  end

  def secure_category_ids
    @secure_category_ids ||= @user.secure_category_ids
  end

  # all allowed category ids
  def allowed_category_ids
    unrestricted = Category.where(read_restricted: false).pluck(:id)
    unrestricted.concat(secure_category_ids)
  end

  def topic_create_allowed_category_ids
    @topic_create_allowed_category_ids ||= @user.topic_create_allowed_category_ids
  end
end
