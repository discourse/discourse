# frozen_string_literal: true

# This constraint accounts for admins who are impersonating other users
# and are therefore currently not identified as admins in their session.
class ImpersonatorConstraint
  def matches?(request)
    current_user = CurrentUser.lookup_from_env(request.env)

    # An admin who's not impersonating anyone. Cool.
    return true if current_user&.admin?

    # An admin who's impersonating someone. Also cool.
    # We know this because only admins can impersonate others.
    return true if current_user&.is_impersonating

    false
  rescue Discourse::InvalidAccess, Discourse::ReadOnly
    false
  end
end
