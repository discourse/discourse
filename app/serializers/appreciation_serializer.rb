# frozen_string_literal: true

class AppreciationSerializer < ApplicationSerializer
  attributes :type, :created_at

  has_one :acting_user, serializer: BasicUserSerializer, embed: :objects
  has_one :post, serializer: GroupPostSerializer, embed: :objects

  attribute :metadata

  def metadata
    object.metadata
  end

  def include_metadata?
    object.metadata.present?
  end
end
