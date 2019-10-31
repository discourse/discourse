# frozen_string_literal: true

class UserAuthTokenSerializer < ApplicationSerializer
  include UserAuthTokensMixin

  attributes :seen_at
  attributes :is_active

  def include_is_active?
    scope && scope.request
  end

  def is_active
    scope.auth_token == object.auth_token
  end

  def seen_at
    return object.created_at unless object.seen_at.present?

    object.seen_at
  end
end
