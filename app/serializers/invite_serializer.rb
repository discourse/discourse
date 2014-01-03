class InviteSerializer < ApplicationSerializer

  attributes :email, :created_at, :redeemed_at
  has_one :user, embed: :objects, serializer: InvitedUserSerializer

  def filter(keys)
    keys.delete(:email) if object.redeemed?
    keys
  end

end
