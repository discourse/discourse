class InviteSerializer < ApplicationSerializer

  attributes :email, :created_at, :redeemed_at, :expired
  has_one :user, embed: :objects, serializer: InvitedUserSerializer

  def include_email?
    !object.redeemed?
  end

  def expired
    object.expired?
  end

end
