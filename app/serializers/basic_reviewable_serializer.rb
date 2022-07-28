# frozen_string_literal: true

class BasicReviewableSerializer < ApplicationSerializer
  attributes :flagger_username, :id, :type, :pending

  def flagger_username
    object.created_by&.username
  end

  def pending
    object.pending?
  end
end
