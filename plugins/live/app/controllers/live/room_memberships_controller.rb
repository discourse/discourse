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

      if role == Live::RoomMembership::ROLE_SPEAKER &&
           ActiveModel::Type::Boolean.new.cast(params[:session_only])
        Live::StageRoles.grant_session_speaker!(@room, user)
        return head :no_content
      end

      membership = Live::StageRoles.assign_role!(@room, user, role: role)

      # Removing a session grant leaves no membership row behind.
      return head :no_content if membership.new_record?

      render_serialized membership, Live::RoomMembershipSerializer, root: :membership
    end

    def update
      guardian.ensure_can_manage_live_room!(@room)
      membership = @room.room_memberships.find(params[:id])
      new_role = params.require(:role)
      role = Live::RoomMembership.role_value(new_role)
      Live::StageRoles.update_membership!(@room, membership, role: role)

      render_serialized membership, Live::RoomMembershipSerializer, root: :membership
    end

    def destroy
      guardian.ensure_can_manage_live_room!(@room)
      membership = @room.room_memberships.find(params[:id])
      Live::StageRoles.remove_membership!(@room, membership)

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
      @room = Live::Room.find(params[:room_id])
    end
  end
end
