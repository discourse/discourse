# frozen_string_literal: true

class GroupRequesterSerializer < BasicUserSerializer
  attributes :reason, :requested_at
end
