# frozen_string_literal: true

module FlagGuardian
  def can_edit_flag?(flag)
    @user.admin? && !flag.system? && !flag.used?
  end

  def can_toggle_flag?
    @user.admin?
  end

  def can_reorder_flag?(flag)
    @user.admin? && flag.name_key != "notify_user"
  end
end
