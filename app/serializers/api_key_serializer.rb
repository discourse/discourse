# frozen_string_literal: true

class ApiKeySerializer < ApplicationSerializer
  root 'api_key'

  attributes :id,
             :key,
             :last_used_at,
             :created_at

  has_one :user, serializer: BasicUserSerializer, embed: :objects

  def include_user_id?
    !object.user_id.nil?
  end

end
