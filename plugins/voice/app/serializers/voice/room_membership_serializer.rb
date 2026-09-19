# frozen_string_literal: true

module Voice
  class RoomMembershipSerializer < ApplicationSerializer
    attributes :id, :room_id, :user_id, :role, :role_name, :created_at, :updated_at

    has_one :user, serializer: BasicUserSerializer, embed: :objects

    def role_name
      object.role_name
    end
  end
end
