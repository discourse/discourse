module CategoryGuardian
  def can_create_category?(parent)
    is_staff?
  end

  def can_edit_category?(category)
    is_staff?
  end

  def can_delete_category?(category)
    is_staff? && category.topic_count == 0
  end

  def can_see_category?(category)
    not(category.read_restricted) || secure_category_ids.include?(category.id)
  end
end
