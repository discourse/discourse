# frozen_string_literal: true

class ReviewableHistorySerializer < ApplicationSerializer
  root 'reviewable_history'

  attributes :id, :reviewable_history_type, :status, :created_at
  has_one :created_by, serializer: BasicUserSerializer, root: 'users'

end
