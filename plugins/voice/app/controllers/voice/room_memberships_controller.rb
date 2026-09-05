# frozen_string_literal: true

module Voice
  class RoomMembershipsController < ApplicationController
    before_action :load_room

    def index
      guardian.ensure_can_manage_voice_room!(@room)
      render_serialized @room.room_memberships, Voice::RoomMembershipSerializer, root: :memberships
    end

    def create
      guardian.ensure_can_manage_voice_room!(@room)
      user = fetch_user
      role = Voice::RoomMembership.role_value(params[:role])
      membership = @room.room_memberships.find_or_initialize_by(user: user)
      membership.role = role
      membership.save!

      if Voice::ParticipantTracker.user_ids(@room.id).include?(user.id)
        metadata = Voice::ParticipantTracker.get_metadata(@room.id, user.id)
        metadata[:role] = membership.role_name
        metadata.delete(:hand_raised_at) if membership.can_speak?
        Voice::ParticipantTracker.update_metadata(@room.id, user.id, metadata)
        Voice::RoomBroadcaster.publish_role_change(@room, user.id, membership.role_name)
        Voice::RoomBroadcaster.publish_participants(@room)
        Voice::Livekit::RoomServiceClient.update_participant(@room, user)
      end

      render_serialized membership, Voice::RoomMembershipSerializer, root: :membership
    end

    def update
      guardian.ensure_can_manage_voice_room!(@room)
      membership = @room.room_memberships.find(params[:id])
      new_role = params.require(:role)
      membership.update!(role: Voice::RoomMembership.role_value(new_role))

      if Voice::ParticipantTracker.user_ids(@room.id).include?(membership.user_id)
        metadata = Voice::ParticipantTracker.get_metadata(@room.id, membership.user_id)
        metadata[:role] = membership.role_name
        metadata.delete(:hand_raised_at) if membership.can_speak?
        Voice::ParticipantTracker.update_metadata(@room.id, membership.user_id, metadata)
        Voice::RoomBroadcaster.publish_role_change(@room, membership.user_id, membership.role_name)
        Voice::RoomBroadcaster.publish_participants(@room)
        # Lets a promoted stage listener publish without reconnecting; on
        # failure the client falls back to re-minting a token and reconnecting.
        Voice::Livekit::RoomServiceClient.update_participant(@room, membership.user)
      end

      render_serialized membership, Voice::RoomMembershipSerializer, root: :membership
    end

    def destroy
      guardian.ensure_can_manage_voice_room!(@room)
      membership = @room.room_memberships.find(params[:id])
      user_id = membership.user_id
      membership.destroy!

      if Voice::ParticipantTracker.user_ids(@room.id).include?(user_id)
        metadata = Voice::ParticipantTracker.get_metadata(@room.id, user_id)
        metadata[:role] = "participant"
        Voice::ParticipantTracker.update_metadata(@room.id, user_id, metadata)
        Voice::RoomBroadcaster.publish_role_change(@room, user_id, "participant")
        Voice::RoomBroadcaster.publish_participants(@room)
        if (user = User.find_by(id: user_id))
          Voice::Livekit::RoomServiceClient.update_participant(@room, user)
        end
      end

      head :no_content
    end

    private

    def fetch_user
      if params[:user_id]
        User.find(params[:user_id])
      elsif params[:username]
        User.find_by_username_or_email(params[:username])
      else
        raise Discourse::InvalidParameters
      end
    end

    def load_room
      @room = Voice::Room.find(params[:room_id])
    end
  end
end
