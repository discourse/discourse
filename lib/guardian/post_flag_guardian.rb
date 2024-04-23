# frozen_string_literal: true

module PostFlagGuardian
  def can_edit_post_flag?(post_flag)
    @user.admin? && !post_flag.system? && !post_flag.used?
  end
end
