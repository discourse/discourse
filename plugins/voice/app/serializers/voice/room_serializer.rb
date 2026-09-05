# frozen_string_literal: true

module Voice
  class RoomSerializer < ApplicationSerializer
    attributes :id,
               :name,
               :slug,
               :description,
               :cooked_description,
               :public,
               :ephemeral,
               :room_type,
               :max_participants,
               :created_at,
               :updated_at,
               :member_count,
               :message_bus_last_id,
               :active_participants,
               :creator_id,
               :can_manage,
               :can_invite,
               :description_excerpt,
               :visit_count,
               :video_enabled,
               :video_allowed,
               :screen_share_allowed,
               :chat_channel_id,
               :chat_idle_minutes,
               :chat_available,
               :livekit_enabled,
               :expected_transport,
               :max_quality_profile,
               :recording,
               :ringing

    has_one :membership, serializer: Voice::RoomMembershipSerializer, embed: :objects

    def include_ringing?
      object.ephemeral?
    end

    # People this call is still reaching out to: unredeemed invites, stamped
    # with when they were last rung so clients can stop showing ones whose
    # ring has run out. The client hides entries for users already present.
    def ringing
      invites = Voice::Invite.where(room_id: object.id, redeemed_at: nil)
      users = User.real.not_staged.where(id: invites.map(&:user_id)).index_by(&:id)

      invites.filter_map do |invite|
        user = users[invite.user_id]
        next unless user

        {
          user: BasicUserSerializer.new(user, scope: scope, root: false).as_json,
          notified_at: invite.updated_at.to_i,
        }
      end
    end

    def membership
      object.room_memberships.find { |membership| membership.user_id == scope.user&.id }
    end

    def member_count
      object.room_memberships.size
    end

    # The directory captures every room position before its live state. Other
    # callers rely on attribute order so concurrent broadcasts replay instead of being missed.
    def message_bus_last_id
      return directory_entry.message_bus_last_id if directory_entry

      MessageBus.last_id(Voice.room_channel(object.id))
    end

    # Each entry carries the sender's own publish entitlements: mesh peers
    # exchange media directly, so a receiver decides whether to play a video
    # or screen-audio track from this, not from its own rights.
    def active_participants
      entitlements = Voice::MediaEntitlements.for_users(object, tracked_participants)

      tracked_participants.map do |user|
        BasicUserSerializer
          .new(user, scope: scope, root: false)
          .as_json
          .merge(participant_metadata[user.id] || {})
          .merge(entitlements[user.id] || Voice::MediaEntitlements::NONE)
      end
    end

    def room_type
      object.room_type_name
    end

    def max_quality_profile
      object.max_quality_profile_name
    end

    def can_manage
      return @can_manage if defined?(@can_manage)
      @can_manage = scope.can_manage_voice_room?(object)
    end

    def can_invite
      scope.can_invite_to_voice_room?(object)
    end

    def description_excerpt
      object.description&.lines&.first&.truncate(150)
    end

    def visit_count
      Voice::Session.where(user_id: scope.user.id, room_id: object.id).count
    end

    def include_visit_count?
      scope.user.present? && @options[:include_visit_count]
    end

    # Per-user publish rights, so they are omitted from the anonymously-scoped
    # directory broadcasts (the client keeps the ones it already knows) and the
    # room's own video_enabled remains the field a broadcast revokes through.
    # The stage role is left out and applied by the client, which follows
    # promotions live.
    def video_allowed
      scope.eligible_to_publish_video_in_voice_room?(object)
    end

    def include_video_allowed?
      scope.user.present?
    end

    def screen_share_allowed
      scope.eligible_to_screen_share_in_voice_room?(object)
    end

    def include_screen_share_allowed?
      scope.user.present?
    end

    def chat_available
      return @chat_available if defined?(@chat_available)

      @chat_available =
        if @options[:chat_availability]&.key?(object.id)
          @options[:chat_availability][object.id]
        else
          Voice::ChatSession.available_for?(object, scope)
        end
    end

    # The room's chat wiring isn't for general consumption: whether chat is
    # usable only matters to someone actually in the room (or managing it),
    # and the channel link plus session settings are only edited by managers.
    # Everyone else — including the anonymously-scoped directory broadcasts —
    # gets a room without chat fields; the client preserves the ones it
    # already knows across those broadcasts.
    def include_chat_available?
      can_manage || participating?
    end

    def include_chat_channel_id?
      can_manage
    end

    def include_chat_idle_minutes?
      can_manage
    end

    # Only the room form consumes this; the live call's transport is never
    # serialized — clients learn it at join.
    def include_livekit_enabled?
      can_manage
    end

    # Best-effort prediction of the transport a join would resolve to right
    # now, mirroring the join endpoint's resolution (pin, then availability).
    # The pin set at join remains authoritative; this exists so clients can
    # warn about mesh's IP exposure before joining, and a race that flips
    # mesh → livekit only makes the warning over-cautious.
    def expected_transport
      pinned_transport =
        if directory_entry
          directory_entry.pinned_transport
        else
          Voice::ParticipantTracker.pinned_transport(object.id)
        end

      pinned_transport || (Voice::Livekit.available_for?(object) ? "livekit" : "mesh")
    end

    # Not gated per user: an active recording is something everyone who can
    # see the room is entitled to know about.
    def recording
      return @recording if defined?(@recording)

      @recording =
        if directory_entry
          directory_entry.recording
        else
          Voice::RecordingManager.status(object.id)
        end
    end

    def include_recording?
      recording.present?
    end

    private

    def directory_entry
      return @directory_entry if defined?(@directory_entry)

      @directory_entry = @options[:directory_entries]&.[](object.id)
    end

    def tracked_participants
      return @tracked_participants if defined?(@tracked_participants)

      @tracked_participants =
        if directory_entry
          directory_entry.participant_users
        else
          Voice::ParticipantTracker.list(object.id)
        end
    end

    def participant_metadata
      return @participant_metadata if defined?(@participant_metadata)

      @participant_metadata =
        if directory_entry
          directory_entry.participant_metadata
        else
          Voice::ParticipantTracker.get_all_metadata(object.id)
        end
    end

    def participating?
      scope.user.present? && tracked_participants.any? { |user| user.id == scope.user.id }
    end
  end
end
