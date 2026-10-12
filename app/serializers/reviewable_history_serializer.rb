# frozen_string_literal: true

class ReviewableHistorySerializer < ApplicationSerializer
  attributes :id, :created_at, :dsa_classification

  attribute :reviewable_history_type_for_database, key: :reviewable_history_type
  attribute :status_for_database, key: :status

  has_one :created_by, serializer: BasicUserSerializer, root: "users"

  def dsa_classification
    object.edited
  end

  def include_dsa_classification?
    object.dsa_classified?
  end
end
