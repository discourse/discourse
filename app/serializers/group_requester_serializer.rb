# frozen_string_literal: true

class GroupRequesterSerializer < BasicUserSerializer
  root 'group_requester'

  attributes :reason, :requested_at
end
