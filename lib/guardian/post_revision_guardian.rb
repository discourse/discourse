# frozen_string_literal: true

# mixin for all Guardian methods dealing with post_revisions permissions
module PostRevisionGuardian

  def can_see_post_revision?(post_revision)
    return false unless post_revision
    return false if post_revision.hidden && !can_view_hidden_post_revisions?

    can_view_edit_history?(post_revision.post)
  end

  def can_hide_post_revision?(post_revision)
    is_staff?
  end

  def can_show_post_revision?(post_revision)
    is_staff?
  end

  def can_view_hidden_post_revisions?
    is_staff?
  end

end
