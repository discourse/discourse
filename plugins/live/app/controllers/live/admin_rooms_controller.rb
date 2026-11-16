# frozen_string_literal: true

module Live
  class AdminRoomsController < ::Admin::AdminController
    requires_plugin "live"

    def index
      rooms = Live::Room.includes(:creator, :room_memberships).order(:name).all

      render_serialized rooms, AdminRoomSerializer, root: :rooms
    end

    def show
      room = Live::Room.includes(:creator, :room_memberships).find(params[:id])
      render_serialized room, AdminRoomSerializer, root: :room
    end

    def create
      room = Live::Room.new(room_params)
      room.creator = current_user

      if room.save
        render_serialized room, AdminRoomSerializer, root: :room, status: :created
      else
        render_json_error room
      end
    end

    def update
      room = Live::Room.find(params[:id])

      if room.update(room_params)
        render_serialized room, AdminRoomSerializer, root: :room
      else
        render_json_error room
      end
    end

    def destroy
      room = Live::Room.find(params[:id])
      room.destroy!
      Live::AgentManager.evict_agents_in_room!(room)
      head :no_content
    end

    # Emergency lever that force-ends a room's live call: evicts the media
    # session from the SFU, unpins the transport so the next join re-resolves
    # against current settings, and sends every participant the same per-user
    # `kicked` message a room-level kick uses — the client handler already
    # forces a clean leave, so no new client message types are needed.
    def end_call
      room = Live::Room.find(params[:id])
      participant_ids = Live::ParticipantTracker.user_ids(room.id)

      Live::AgentManager.evict_agents_in_room!(room)
      participant_ids.each { |user_id| Live::RoomBroadcaster.publish_kick(room, user_id) }

      head :no_content
    end

    private

    def room_params
      permitted =
        params.require(:room).permit(
          :name,
          :slug,
          :description,
          :public,
          :max_participants,
          :room_type,
          :video_enabled,
          :livekit_enabled,
          :chat_channel_id,
          :chat_idle_minutes,
          :max_quality_profile,
        )
      if permitted.key?(:room_type)
        permitted[:room_type] = Live::Room.room_type_from_name!(permitted[:room_type])
      end
      if permitted.key?(:max_quality_profile)
        permitted[:max_quality_profile] = Live::Room::QUALITY_PROFILES[
          permitted[:max_quality_profile].to_s
        ]
      end
      permitted
    end
  end
end
