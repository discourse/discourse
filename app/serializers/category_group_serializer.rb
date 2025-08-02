# frozen_string_literal: true

class CategoryGroupSerializer < ApplicationSerializer
  has_one :category, serializer: CategorySerializer, embed: :objects
  has_one :group, serializer: BasicGroupSerializer, embed: :objects

  attributes :permission_type
end
