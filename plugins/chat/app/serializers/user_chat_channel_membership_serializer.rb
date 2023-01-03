# frozen_string_literal: true

class UserChatChannelMembershipSerializer < BaseChatChannelMembershipSerializer
  has_one :user, serializer: BasicUserSerializer, embed: :objects

  def user
    object.user
  end
end
