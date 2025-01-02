# frozen_string_literal: true

class BasicApiKeySerializer < ApplicationSerializer
  attributes :id, :truncated_key, :description, :created_at, :last_used_at, :revoked_at

  has_one :user, serializer: BasicUserSerializer, embed: :objects
  has_one :created_by, serializer: BasicUserSerializer, embed: :objects
end
