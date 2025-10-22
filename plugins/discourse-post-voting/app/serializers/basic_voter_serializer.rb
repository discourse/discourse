# frozen_string_literal: true

class BasicVoterSerializer < ApplicationSerializer
  attributes :id, :username, :name, :avatar_template, :direction

  def direction
    object.direction
  end
end
