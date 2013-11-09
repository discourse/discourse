class InviteSerializer < ApplicationSerializer

  attributes :email, :created_at, :redeemed_at
  has_one :user, embed: :objects, serializer: InvitedUserSerializer

  def include_email?
    !object.redeemed?
  end

end
