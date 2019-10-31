# frozen_string_literal: true

class DirectorySerializer < ApplicationSerializer
  attributes :id
  has_many :directory_items, serializer: DirectoryItemSerializer, embed: :objects

  def id
    object.filter
  end

end
