# frozen_string_literal: true

module Chat
  class UserChannelMembershipSerializer < BaseChannelMembershipSerializer
    has_one :user, serializer: ::Chat::BasicUserSerializer, embed: :objects

    def user
      object.user || Chat::NullUser.new
    end
  end
end
