# frozen_string_literal: true

module Voice
  class AdminRoomsController < ::Admin::AdminController
    requires_plugin "voice"

    def index
      rooms = Voice::Room.includes(:creator, :room_memberships).order(:name).all

      render_serialized rooms, AdminRoomSerializer, root: :rooms
    end

    def show
      room = Voice::Room.includes(:creator, :room_memberships).find(params[:id])
      render_serialized room, AdminRoomSerializer, root: :room
    end

    def create
      room = Voice::Room.new(room_params)
      room.creator = current_user

      if room.save
        render_serialized room, AdminRoomSerializer, root: :room, status: :created
      else
        render_json_error room
      end
    end

    def update
      room = Voice::Room.find(params[:id])

      if room.update(room_params)
        render_serialized room, AdminRoomSerializer, root: :room
      else
        render_json_error room
      end
    end

    def destroy
      room = Voice::Room.find(params[:id])
      room.destroy!
      Voice::Livekit::RoomServiceClient.delete_room(room)
      Voice::ParticipantTracker.clear_transport_pin(room.id)
      head :no_content
    end

    # Emergency lever that force-ends a room's live call: evicts the media
    # session from the SFU, unpins the transport so the next join re-resolves
    # against current settings, and sends every participant the same per-user
    # `kicked` message a room-level kick uses — the client handler already
    # forces a clean leave, so no new client message types are needed.
    def end_call
      room = Voice::Room.find(params[:id])
      participant_ids = Voice::ParticipantTracker.user_ids(room.id)

      Voice::Livekit::RoomServiceClient.delete_room(room)
      Voice::ParticipantTracker.clear_transport_pin(room.id)
      participant_ids.each { |user_id| Voice::RoomBroadcaster.publish_kick(room, user_id) }

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
        permitted[:room_type] = Voice::Room.room_type_from_name!(permitted[:room_type])
      end
      if permitted.key?(:max_quality_profile)
        permitted[:max_quality_profile] = Voice::Room::QUALITY_PROFILES[
          permitted[:max_quality_profile].to_s
        ]
      end
      permitted
    end
  end
end
