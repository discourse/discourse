# frozen_string_literal: true

module FlagGuardian
  def can_edit_flag?(flag)
    @user.admin? && !flag.system? && !flag.used?
  end
end
