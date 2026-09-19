# frozen_string_literal: true

class BasicVoterSerializer < BasicUserSerializer
  attributes :direction

  def direction
    object.direction
  end
end
