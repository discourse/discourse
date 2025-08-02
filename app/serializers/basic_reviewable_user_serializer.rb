# frozen_string_literal: true

class BasicReviewableUserSerializer < BasicReviewableSerializer
  attributes :username

  def username
    object.payload["username"]
  end
end
