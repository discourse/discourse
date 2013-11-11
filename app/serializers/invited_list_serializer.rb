class InvitedListSerializer < ApplicationSerializer

  has_many :pending, serializer: InviteSerializer, embed: :objects
  has_many :redeemed, serializer: InviteSerializer, embed: :objects


  def include_pending?
    scope.can_see_pending_invites_from?(object.by_user)
  end
end
