# frozen_string_literal: true

class InvitedUserSerializer < ApplicationSerializer
  attributes :id, :redeemed_at, :user, :invite_source

  def id
    object.invite.id
  end

  def user
    ser = InvitedUserRecordSerializer.new(object.user, scope: scope, root: false)
    ser.invited_by = object.invite.invited_by
    ser.as_json
  end

  def invite_source
    object.invite.is_invite_link? ? "link" : "email"
  end
end
