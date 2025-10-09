# frozen_string_literal: true

module FlagGuardian
  def can_edit_flag?(flag)
    @user.admin? && !flag.system?
  end

  def can_create_flag?
    @user.admin? && Flag.custom.count < SiteSetting.custom_flags_limit
  end

  def can_toggle_flag?
    return fail("not an admin") if !@user.admin?

    pass
  end

  def can_reorder_flag?(flag)
    @user.admin? && flag.name_key != "notify_user"
  end
end
