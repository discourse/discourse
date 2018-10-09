class UserAuthTokenSerializer < ApplicationSerializer
  include UserAuthTokensMixin

  attributes :seen_at
  attributes :is_active

  def include_is_active?
    scope && scope.request
  end

  def is_active
    cookie = scope.request.cookies[Auth::DefaultCurrentUserProvider::TOKEN_COOKIE]

    UserAuthToken.hash_token(cookie) == object.auth_token
  end

  def seen_at
    return object.created_at unless object.seen_at.present?

    object.seen_at
  end
end
