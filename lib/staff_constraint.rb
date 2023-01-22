# frozen_string_literal: true

class StaffConstraint
  def matches?(request)
    current_user = CurrentUser.lookup_from_env(request.env)
    current_user&.staff? && custom_staff_check(request)
  rescue Discourse::InvalidAccess, Discourse::ReadOnly
    false
  end

  # Extensibility point: plugins can overwrite this to add additional checks
  # if they require.
  def custom_staff_check(request)
    true
  end
end
