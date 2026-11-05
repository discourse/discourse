# frozen_string_literal: true

module Live
  class RoomMembershipsController < ApplicationController
    before_action :load_room

    def index
      guardian.ensure_can_manage_live_room!(@room)
      render_serialized @room.room_memberships, Live::RoomMembershipSerializer, root: :memberships
    end

    def create
      guardian.ensure_can_manage_live_room!(@room)
      user = fetch_user
      role = Live::RoomMembership.role_value(params[:role])
      ensure_agent_role_allowed!(user)
      membership = @room.room_memberships.find_or_initialize_by(user: user)
      membership.role = role
      membership.save!

      if Live::ParticipantTracker.user_ids(@room.id).include?(user.id)
        metadata = Live::ParticipantTracker.get_metadata(@room.id, user.id)
        metadata[:role] = membership.role_name
        metadata.delete(:hand_raised_at) if membership.can_speak?
        Live::ParticipantTracker.update_metadata(@room.id, user.id, metadata)
        Live::RoomBroadcaster.publish_role_change(@room, user.id, membership.role_name)
        Live::RoomBroadcaster.publish_participants(@room)
        Live::Livekit::RoomServiceClient.update_participant(@room, user)
      end

      render_serialized membership, Live::RoomMembershipSerializer, root: :membership
    end

    def update
      guardian.ensure_can_manage_live_room!(@room)
      membership = @room.room_memberships.find(params[:id])
      new_role = params.require(:role)
      role = Live::RoomMembership.role_value(new_role)
      ensure_agent_role_allowed!(membership.user)
      membership.update!(role: role)

      if Live::ParticipantTracker.user_ids(@room.id).include?(membership.user_id)
        metadata = Live::ParticipantTracker.get_metadata(@room.id, membership.user_id)
        metadata[:role] = membership.role_name
        metadata.delete(:hand_raised_at) if membership.can_speak?
        Live::ParticipantTracker.update_metadata(@room.id, membership.user_id, metadata)
        Live::RoomBroadcaster.publish_role_change(@room, membership.user_id, membership.role_name)
        Live::RoomBroadcaster.publish_participants(@room)
        # Lets a promoted stage listener publish without reconnecting; on
        # failure the client falls back to re-minting a token and reconnecting.
        Live::Livekit::RoomServiceClient.update_participant(@room, membership.user)
      end

      render_serialized membership, Live::RoomMembershipSerializer, root: :membership
    end

    def destroy
      guardian.ensure_can_manage_live_room!(@room)
      membership = @room.room_memberships.find(params[:id])
      user_id = membership.user_id
      membership.destroy!

      if Live::ParticipantTracker.user_ids(@room.id).include?(user_id)
        metadata = Live::ParticipantTracker.get_metadata(@room.id, user_id)
        metadata[:role] = "participant"
        Live::ParticipantTracker.update_metadata(@room.id, user_id, metadata)
        Live::RoomBroadcaster.publish_role_change(@room, user_id, "participant")
        Live::RoomBroadcaster.publish_participants(@room)
        if (user = User.find_by(id: user_id))
          Live::Livekit::RoomServiceClient.update_participant(@room, user)
        end
      end

      head :no_content
    end

    private

    def ensure_agent_role_allowed!(user)
      raise Discourse::InvalidParameters.new(:user_id) if user.bot?
    end

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
      @room = Live::Room.find(params[:room_id])
    end
  end
end
