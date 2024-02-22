# frozen_string_literal: true

module Chat
  class UserChannelMembershipSerializer < BaseChannelMembershipSerializer
    has_one :user, serializer: ::Chat::ChatableUserSerializer, embed: :objects

    def user
      object.user || Chat::NullUser.new
    end
  end
end
