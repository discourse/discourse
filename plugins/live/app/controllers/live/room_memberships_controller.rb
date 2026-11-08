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

      membership =
        Live::StageRoles.assign!(@room, user, role: role, session_only: session_only_param)

      render_serialized membership, Live::RoomMembershipSerializer, root: :membership
    end

    def update
      guardian.ensure_can_manage_live_room!(@room)
      membership = @room.room_memberships.find(params[:id])
      role = Live::RoomMembership.role_value(params.require(:role))
      ensure_agent_role_allowed!(membership.user)

      membership =
        Live::StageRoles.assign!(
          @room,
          membership.user,
          role: role,
          session_only: session_only_param,
        )

      render_serialized membership, Live::RoomMembershipSerializer, root: :membership
    end

    def destroy
      guardian.ensure_can_manage_live_room!(@room)
      membership = @room.room_memberships.find(params[:id])
      Live::StageRoles.remove!(@room, membership)

      head :no_content
    end

    private

    def session_only_param
      ActiveModel::Type::Boolean.new.cast(params[:session_only]) || false
    end

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
