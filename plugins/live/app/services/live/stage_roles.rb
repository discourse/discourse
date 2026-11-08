# frozen_string_literal: true

module Live
  # Role changes in a Stage room, shared by the memberships API and the
  # speak-invitation flow so promotion and demotion keep the live roster, the
  # clients and the SFU in step.
  class StageRoles
    class << self
      # `session_only` grants speaker for the current session only: the role
      # reverts when the room empties (see clear_session_speakers!). It never
      # downgrades a permanent speaker or moderator.
      def assign!(room, user, role:, session_only: false)
        membership = room.room_memberships.find_or_initialize_by(user: user)
        session_only &&= role == Live::RoomMembership::ROLE_SPEAKER

        if session_only && membership.persisted? && membership.can_speak?
          session_only = false
          role = membership.role
        end

        if session_only
          membership.fallback_role = membership.persisted? ? membership.role : nil
          membership.session_only = true
        else
          membership.fallback_role = nil
          membership.session_only = false
        end

        membership.role = role
        membership.save!
        sync_participant(room, user.id, membership.role_name, user: user)
        membership
      end

      def remove!(room, membership)
        user_id = membership.user_id
        membership.destroy!
        sync_participant(room, user_id, "participant")
      end

      # Called when a room empties (or a user is removed from it): temporary
      # speakers drop back to what they were before the grant.
      def clear_session_speakers!(room_id, user_id: nil)
        scope = Live::RoomMembership.where(room_id: room_id, session_only: true)
        scope = scope.where(user_id: user_id) if user_id

        scope.where(fallback_role: nil).delete_all
        scope
          .where.not(fallback_role: nil)
          .update_all("role = fallback_role, session_only = FALSE, fallback_role = NULL")
      end

      # Pushes a role change into the live call: roster metadata, the
      # role_change event, the roster broadcast and the SFU permissions. A
      # user who can no longer speak also has their published state reset, so
      # the roster does not keep showing a demoted speaker as unmuted or
      # sharing until their client next reports in.
      def sync_participant(room, user_id, role_name, user: nil)
        return if Live::ParticipantTracker.user_ids(room.id).exclude?(user_id)

        user ||= User.find_by(id: user_id)
        metadata = Live::ParticipantTracker.get_metadata(room.id, user_id)
        metadata[:role] = role_name

        if can_speak?(room, user, role_name)
          metadata.delete(:hand_raised_at)
          metadata.delete(:speak_invited_at)
        elsif room.stage?
          metadata[:is_muted] = true
          metadata[:is_video_on] = false
          metadata[:is_screen_sharing] = false
        end

        Live::ParticipantTracker.update_metadata(room.id, user_id, metadata)
        Live::RoomBroadcaster.publish_role_change(room, user_id, role_name)
        Live::RoomBroadcaster.publish_participants(room)
        # Lets a promoted stage listener publish without reconnecting; on
        # failure the client falls back to re-minting a token and reconnecting.
        Live::Livekit::RoomServiceClient.update_participant(room, user) if user
      end

      private

      def can_speak?(room, user, role_name)
        return true if room.open?
        return true if %w[speaker moderator].include?(role_name)

        !!user&.admin?
      end
    end
  end
end
