# frozen_string_literal: true

class VoiceCreditSerializer < ActiveModel::Serializer
  attributes :id, :user_id, :topic_id, :credits_allocated
end
