# frozen_string_literal: true

class ReviewableNoteSerializer < ApplicationSerializer
  attributes :id, :content, :created_at, :updated_at

  has_one :user, serializer: BasicUserSerializer, embed: :objects
end
