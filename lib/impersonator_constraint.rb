# frozen_string_literal: true

class ImpersonatorConstraint
  def matches?(request)
    current_user = CurrentUser.lookup_from_env(request.env)
    !!current_user&.is_impersonating
  rescue Discourse::InvalidAccess, Discourse::ReadOnly
    false
  end
end
