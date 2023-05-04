# frozen_string_literal: true

class InactiveUserSerializer < BasicUserSerializer
  attributes :inactive

  def inactive
    !object.active?
  end
end
