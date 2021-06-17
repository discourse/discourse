# frozen_string_literal: true

class DirectoryColumnSerializer < ApplicationSerializer
  attributes :id,
             :name,
             :type,
             :enabled,
             :automatic_position,
             :position,
             :icon

  has_one :user_field, serializer: UserFieldSerializer, embed: :objects
end
