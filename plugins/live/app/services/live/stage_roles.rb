# frozen_string_literal: true

module Live
  # Centralizes stage role transitions, session-only speaker lifecycles,
  # demotion media cleanup, moderator remote mutes, and live room-type switches.
  class StageRoles
    class << self
      def effective_role(room, user, membership: :lookup)
        return "participant" if user.blank?

        membership = room.membership_for(user) if membership == :lookup
        return "moderator" if room.stage? && user.admin?
        return membership.role_name if membership&.can_speak?
        return "speaker" if session_speaker?(room, user.id)

        membership&.role_name || "participant"
      end

      def session_speaker?(room, user_id)
        room.stage? && Live::ParticipantTracker.session_speaker?(room.id, user_id)
      end

      # A session grant lives with the room's live state and never touches
      # the membership, so a permanent role is neither downgraded nor lost.
      def grant_session_speaker!(room, user)
        raise Discourse::InvalidParameters.new(:user_id) if user.bot?

        membership = room.membership_for(user)
        Live::ParticipantTracker.add_session_speaker(room.id, user.id) if !membership&.can_speak?

        sync_present_participant!(
          room,
          user,
          effective_role: effective_role(room, user, membership: membership),
        )
      end

      def assign_role!(room, user, role:)
        raise Discourse::InvalidParameters.new(:user_id) if user.bot?

        membership = room.room_memberships.find_or_initialize_by(user: user)
        had_grant = Live::ParticipantTracker.remove_session_speaker(room.id, user.id)

        # Demoting someone who only held a session grant needs no row.
        unless had_grant && membership.new_record? && role == Live::RoomMembership::ROLE_PARTICIPANT
          membership.role = role
          membership.save!
        end

        sync_present_participant!(
          room,
          user,
          effective_role: effective_role(room, user, membership: membership),
        )

        membership
      end

      def update_membership!(room, membership, role:)
        raise Discourse::InvalidParameters.new(:user_id) if membership.user.bot?

        membership.update!(role: role)
        Live::ParticipantTracker.remove_session_speaker(room.id, membership.user_id)

        sync_present_participant!(
          room,
          membership.user,
          effective_role: effective_role(room, membership.user, membership: membership),
        )

        membership
      end

      def remove_membership!(room, membership)
        user_id = membership.user_id
        membership.destroy!
        Live::ParticipantTracker.remove_session_speaker(room.id, user_id)

        return :evicted if Live::ParticipantEvictor.evict_unless_authorized!(room, user_id)

        if (user = User.find_by(id: user_id))
          sync_present_participant!(
            room,
            user,
            effective_role: effective_role(room, user, membership: nil),
          )
        end

        :removed
      end

      def step_down!(room, user)
        membership = room.room_memberships.find_by(user_id: user.id)
        had_grant = Live::ParticipantTracker.remove_session_speaker(room.id, user.id)
        if !had_grant && membership&.speaker?
          membership.update!(role: Live::RoomMembership::ROLE_PARTICIPANT)
        end

        sync_present_participant!(
          room,
          user,
          effective_role: effective_role(room, user, membership: membership),
        )
      end

      def revoke_session_speaker!(room, user_id)
        Live::ParticipantTracker.remove_session_speaker(room.id, user_id)
      end

      def clear_session_speakers!(room)
        Live::ParticipantTracker.clear_session_speakers(room.id)
      end

      def mute_participant!(room, target_user, acting_user:)
        if Live::ParticipantTracker.user_ids(room.id).exclude?(target_user.id)
          raise Discourse::InvalidParameters.new(:user_id)
        end

        metadata = Live::ParticipantTracker.get_metadata(room.id, target_user.id)
        metadata[:is_muted] = true
        Live::ParticipantTracker.update_metadata(room.id, target_user.id, metadata)

        Live::RoomBroadcaster.publish_force_mute(room, target_user.id, muted_by: acting_user)
        Live::RoomBroadcaster.publish_participants(room)
        Live::Livekit::RoomServiceClient.mute_participant_audio(room, target_user.id)
      end

      def sync_room_type_change!(room)
        clear_session_speakers!(room) if room.open?

        active_ids = Live::ParticipantTracker.human_user_ids(room.id)
        return if active_ids.empty?

        users = User.where(id: active_ids).index_by(&:id)
        memberships = room.room_memberships.where(user_id: active_ids).index_by(&:user_id)

        active_ids.each do |user_id|
          user = users[user_id]
          next unless user

          role = effective_role(room, user, membership: memberships[user_id])
          metadata = Live::ParticipantTracker.get_metadata(room.id, user_id)
          metadata[:role] = role

          if room.stage? && !user.guardian.can_speak_in_live_room?(room)
            metadata[:is_muted] = true
            metadata[:is_video_on] = false
            metadata[:is_screen_sharing] = false
          elsif room.open?
            metadata.delete(:hand_raised_at)
            Live::ParticipantTracker.clear_speak_invitation(room.id, user_id)
            metadata = Live::ParticipantTracker.get_metadata(room.id, user_id)
            metadata[:role] = role
            metadata.delete(:hand_raised_at)
          end

          Live::ParticipantTracker.update_metadata(room.id, user_id, metadata)
          Live::Livekit::RoomServiceClient.update_participant(room, user)
        end

        Live::RoomBroadcaster.publish_participants(room)
      end

      def sync_present_participant!(room, user, effective_role:)
        return if Live::ParticipantTracker.user_ids(room.id).exclude?(user.id)

        can_speak = room.open? || %w[moderator speaker].include?(effective_role)

        if can_speak
          Live::ParticipantTracker.clear_speak_invitation(room.id, user.id)
          Live::ParticipantTracker.clear_hand_raise_cooldown(room.id, user.id)
        end

        metadata = Live::ParticipantTracker.get_metadata(room.id, user.id)
        was_speaker = %w[moderator speaker].include?(metadata[:role])
        metadata[:role] = effective_role

        if can_speak
          metadata.delete(:hand_raised_at)
          # Only a stage listener is force-muted server-side; anywhere else the
          # flag is the client's own reported state.
          metadata[:is_muted] = false if room.stage? && !was_speaker
        else
          # Immediately clear published-media indicators on demotion rather
          # than waiting for the demoted client to report back.
          metadata[:is_muted] = true
          metadata[:is_video_on] = false
          metadata[:is_screen_sharing] = false
        end

        Live::ParticipantTracker.update_metadata(room.id, user.id, metadata)
        Live::RoomBroadcaster.publish_role_change(room, user.id, effective_role)
        Live::RoomBroadcaster.publish_participants(room)
        Live::Livekit::RoomServiceClient.update_participant(room, user)
      end
    end
  end
end
