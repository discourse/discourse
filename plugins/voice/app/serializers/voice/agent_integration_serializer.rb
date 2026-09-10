# frozen_string_literal: true

module Voice
  class AgentIntegrationSerializer < ApplicationSerializer
    attributes :id,
               :name,
               :room_ids,
               :role,
               :revoked_at,
               :created_at,
               :updated_at,
               :excluded_room_ids

    has_one :bot_user, serializer: BasicUserSerializer, embed: :objects

    def room_ids
      object.integration_rooms.map(&:room_id)
    end

    def role
      object.role_name
    end

    def excluded_room_ids
      object
        .exclusions
        .select { |exclusion| exclusion.expires_at.nil? || exclusion.expires_at > Time.current }
        .map(&:room_id)
    end
  end
end
