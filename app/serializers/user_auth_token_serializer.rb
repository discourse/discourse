# frozen_string_literal: true

class UserAuthTokenSerializer < ApplicationSerializer
  include UserAuthTokensMixin

  attributes :seen_at
  attributes :is_active

  def id
    object[:device_id] || object.id
  end

  def include_is_active?
    scope && scope.request
  end

  def is_active
    return object.current_device if object.has_attribute?(:current_device)

    scope.auth_token_id == object.id
  end

  def seen_at
    return object.created_at if object.seen_at.blank?

    object.seen_at
  end
end
