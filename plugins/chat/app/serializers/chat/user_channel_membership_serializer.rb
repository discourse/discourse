# frozen_string_literal: true

module Chat
  class UserChannelMembershipSerializer < BaseChannelMembershipSerializer
    has_one :user, embed: :objects

    def user
      user = object.user || Chat::NullUser.new
      Chat::BasicUserSerializer.new(user, root: false, scope: scope, include_status: true)
    end
  end
end
