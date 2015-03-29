class InviteSerializer < ApplicationSerializer

  attributes :email, :created_at, :redeemed_at, :expired, :user

  def include_email?
    !object.redeemed?
  end

  def expired
    object.expired?
  end

  def user
    ser = InvitedUserSerializer.new(object.user, scope: scope, root: false)
    ser.invited_by = object.invited_by
    ser.as_json
  end

end
