# frozen_string_literal: true

#mixin for all guardian methods dealing with category permissions
module CategoryGuardian
  # Creating Method
  def can_create_category?(parent = nil)
    is_admin? || (SiteSetting.moderators_manage_categories && is_moderator?)
  end

  # Editing Method
  def can_edit_category?(category)
    is_admin? ||
      (SiteSetting.moderators_manage_categories && is_moderator? && can_see_category?(category))
  end

  def can_edit_serialized_category?(category_id:, read_restricted:)
    is_admin? ||
      (
        SiteSetting.moderators_manage_categories && is_moderator? &&
          can_see_serialized_category?(category_id: category_id, read_restricted: read_restricted)
      )
  end

  def can_delete_category?(category)
    can_edit_category?(category) && category.topic_count <= 0 && !category.uncategorized? &&
      !category.has_children?
  end

  def can_see_serialized_category?(category_id:, read_restricted: true)
    # Guard to ensure only a boolean is passed in
    read_restricted = true unless !!read_restricted == read_restricted

    return true if !read_restricted
    secure_category_ids.include?(category_id)
  end

  def can_see_category?(category)
    return false unless category
    return true if is_admin? && !SiteSetting.suppress_secured_categories_from_admin
    return true if !category.read_restricted
    return true if is_staged? && category.email_in.present? && category.email_in_allow_strangers
    secure_category_ids.include?(category.id)
  end

  def can_post_in_category?(category)
    return false unless category
    return false if is_anonymous?
    return true if is_admin?
    Category.post_create_allowed(self).exists?(id: category.id)
  end

  def can_edit_category_description?(category)
    can_perform_action_available_to_group_moderators?(category.topic)
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

  def topic_featured_link_allowed_category_ids
    @topic_featured_link_allowed_category_ids =
      Category.where(topic_featured_link_allowed: true).pluck(:id)
  end

  def topic_posting_review_required?(category)
    posting_review_required?(category, :topic)
  end

  def reply_posting_review_required?(category)
    posting_review_required?(category, :reply)
  end

  private

  def posting_review_required?(category, post_type)
    return false if category.nil?

    mode = category.category_setting.public_send(:"#{post_type}_posting_review_mode")
    case mode
    when "no_one"
      false
    when "everyone"
      true
    when "everyone_except"
      !CategoryPostingReviewGroup.user_in_group?(
        category: category,
        user: @user,
        post_type: post_type,
      )
    when "no_one_except"
      CategoryPostingReviewGroup.user_in_group?(
        category: category,
        user: @user,
        post_type: post_type,
      )
    else
      false
    end
  end
end
