# frozen_string_literal: true

module Voice
  class InvitesController < ApplicationController
    MAX_USERS_PER_REQUEST = 10
    SUGGESTION_LIMIT = 10

    before_action :load_room

    def create
      guardian.ensure_can_invite_to_voice_room!(@room)
      RateLimiter.new(current_user, "voice-invites", 10, 1.minute).performed!

      # Bounded before any normalization or query construction: `limit` below
      # caps the rows returned, not the size of the IN list an oversized
      # parameter would otherwise be interpolated into.
      usernames = Array.wrap(params.require(:usernames))
      if usernames.blank? || usernames.size > MAX_USERS_PER_REQUEST
        raise Discourse::InvalidParameters.new(:usernames)
      end
      usernames = usernames.map(&:to_s).uniq

      users =
        User
          .real
          .not_staged
          .where(username_lower: usernames.map(&:downcase))
          .limit(MAX_USERS_PER_REQUEST)

      invited = Voice::RoomInviter.invite!(room: @room, inviter: current_user, users: users)
      # Users the inviter named but the inviter service refused (no access to
      # voice, can't join this room, …) — surfaced so the modal can explain
      # instead of failing silently.
      skipped = users.to_a - invited
      render json: {
               invited_usernames: invited.map(&:username),
               skipped_usernames: skipped.map(&:username),
             }
    end

    # People the current user has shared this room with recently, most time
    # together first — the shortlist the invite modal opens with.
    def suggestions
      guardian.ensure_can_invite_to_voice_room!(@room)

      rows =
        if SiteSetting.voice_analytics_enabled
          Voice::Session.top_room_companions_for(
            current_user.id,
            @room.id,
            since: 30.days.ago,
            # Overfetched so dropping whoever is already in the call cannot
            # leave the list short.
            limit: SUGGESTION_LIMIT * 2,
          )
        else
          []
        end

      present_ids = Voice::ParticipantTracker.user_ids(@room.id)
      rows = rows.reject { |row| present_ids.include?(row.companion_id) }

      users = User.real.not_staged.where(id: rows.map(&:companion_id)).index_by(&:id)

      suggestions =
        rows
          .filter_map do |row|
            user = users[row.companion_id]
            next unless user
            # Session history outlives group membership: only people who can
            # still use voice rooms are worth suggesting.
            next unless user.guardian.can_access_voice?

            BasicUserSerializer
              .new(user, scope: guardian, root: false)
              .as_json
              .merge(total_seconds: row.total_seconds, last_together_at: row.last_together_at)
          end
          .first(SUGGESTION_LIMIT)

      render json: { suggestions: suggestions }
    end

    private

    def load_room
      @room = Voice::Room.find(params[:room_id])
    end
  end
end
