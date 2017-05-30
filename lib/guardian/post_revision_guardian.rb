# mixin for all Guardian methods dealing with post_revisions permissions
module PostRevisionGuardian

  def can_see_post_revision?(post_revision)
    return false unless post_revision
    return false if post_revision.hidden && !can_view_hidden_post_revisions?(post_revision)

    can_view_edit_history?(post_revision.post)
  end

  def can_hide_post_revision?(post_revision)
    is_staff?
  end

  def can_show_post_revision?(post_revision)
    is_staff?
  end

  def can_view_hidden_post_revisions?(post_revision)
    return false unless authenticated?
    post_revision.post.user_id == @user.id || is_staff?
  end

end
