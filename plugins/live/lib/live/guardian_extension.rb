# frozen_string_literal: true

module Live
  module GuardianExtension
    # Access means participating — joining rooms, calling, appearing in
    # rosters — so it always requires authentication. Anonymous visitors are
    # served read-only through live_public_access? instead.
    def can_access_live?
      SiteSetting.live_enabled? && authenticated? &&
        in_any_groups?(SiteSetting.live_allowed_groups_map)
    end

    # Whether Live is open to anonymous visitors, letting them browse (but
    # not join) public rooms. Never true on login-required sites, where there
    # are no anonymous visitors to serve.
    def live_public_access?
      return false unless SiteSetting.live_enabled?
      return false if SiteSetting.login_required

      SiteSetting.live_allowed_groups_map.include?(Group::AUTO_GROUPS[:anonymous_users])
    end

    def can_create_live_room?
      return false unless can_access_live?
      user.in_any_groups?(SiteSetting.live_create_room_allowed_groups_map)
    end

    # Starting a direct call is gated separately from receiving one: anyone
    # with live-room access can be called, but only these groups get the
    # call button and the calls endpoint.
    def can_start_live_call?
      return false unless can_access_live?
      user.in_any_groups?(SiteSetting.live_direct_calls_allowed_groups_map)
    end

    # A specific user may be rung only by callers they could receive a
    # personal message from: muting or ignoring the caller, disabling
    # personal messages, or an allowlist that omits the caller all block the
    # call. Staff are exempt, as they are for personal messages.
    def can_call_live_user?(target)
      return false unless can_start_live_call?
      return false if target.blank? || target.bot? || target.id == user.id
      return false unless target.guardian.can_access_live?

      !UserCommScreener.new(
        acting_user: user,
        target_user_ids: [target.id],
      ).disallowing_pms_from_actor?(target.id)
    end

    # Being allowed to create rooms grants nothing over other people's rooms:
    # a room is managed by site staff, its creator, and its moderators only.
    def can_manage_live_room?(room)
      return false unless can_access_live?
      return false unless room

      is_staff? || room.creator_id == user.id || room.moderator?(user)
    end

    def ensure_can_manage_live_room!(room)
      unless can_manage_live_room?(room)
        raise Discourse::InvalidAccess.new(I18n.t("live.errors.not_authorized"))
      end
    end

    # Deleting discards the room for everyone, so it stays with its owner and
    # staff rather than extending to room moderators. Ephemeral rooms are torn
    # down by their own lifecycle.
    def can_delete_live_room?(room)
      return false unless can_access_live?
      return false if !room || room.ephemeral?

      is_staff? || room.creator_id == user.id
    end

    def ensure_can_delete_live_room!(room)
      unless can_delete_live_room?(room)
        raise Discourse::InvalidAccess.new(I18n.t("live.errors.not_authorized"))
      end
    end

    def ensure_can_create_live_room!
      unless can_create_live_room?
        raise Discourse::InvalidAccess.new(I18n.t("live.errors.not_authorized"))
      end
    end

    def can_join_live_room?(room)
      return false unless can_access_live?
      return false unless room

      room.public? || room.member?(user) || can_manage_live_room?(room)
    end

    def ensure_can_join_live_room!(room)
      unless can_join_live_room?(room)
        raise Discourse::InvalidAccess.new(I18n.t("live.errors.not_authorized"))
      end
    end

    # Inviting is sharing access you already have: anyone who can join a
    # public room may invite others to it, while a private room's roster is a
    # management concern — inviting there grants a membership.
    def can_invite_to_live_room?(room)
      return false unless can_join_live_room?(room)

      room.public? || can_manage_live_room?(room)
    end

    # Room-independent half of can_invite_live_agent?, so the client can learn
    # whether to offer the action before any room is chosen.
    def can_invite_live_agents?
      return false unless can_access_live?
      user.in_any_groups?(SiteSetting.live_livekit_agent_invite_allowed_groups_map)
    end

    def can_invite_live_agent?(room)
      can_invite_live_agents? && can_join_live_room?(room) && room.public? &&
        Live::AgentBot.available?
    end

    def ensure_can_invite_to_live_room!(room)
      unless can_invite_to_live_room?(room)
        raise Discourse::InvalidAccess.new(I18n.t("live.errors.not_authorized"))
      end
    end

    def can_see_live_room?(room)
      return false unless room
      return true if can_join_live_room?(room)

      # Anonymous and not-yet-authorized visitors may browse public rooms when
      # access is open to everyone. Joining still requires authentication.
      live_public_access? && room.public?
    end

    def ensure_can_see_live_room!(room)
      unless can_see_live_room?(room)
        raise Discourse::InvalidAccess.new(I18n.t("live.errors.not_authorized"))
      end
    end

    def can_flag_live_user?(room, target_user)
      return false unless can_join_live_room?(room)
      return false if target_user.blank? || target_user.bot?

      target_user.id != user.id
    end

    def ensure_can_flag_live_user!(room, target_user)
      unless can_flag_live_user?(room, target_user)
        raise Discourse::InvalidAccess.new(I18n.t("live.errors.not_authorized"))
      end
    end

    def can_speak_in_live_room?(room)
      return true if room.open?
      return true if user&.admin?
      membership = room.membership_for(user)
      membership&.can_speak? || false
    end

    # Camera and screen sharing are gated independently, per user: the room
    # must allow media at all, the user must be able to speak in it (a stage
    # listener publishes nothing), and their groups must carry the capability.
    def can_publish_video_in_live_room?(room)
      eligible_to_publish_video_in_live_room?(room) && live_room_media_live?(room)
    end

    def can_screen_share_in_live_room?(room)
      eligible_to_screen_share_in_live_room?(room) && live_room_media_live?(room)
    end

    # The same capability minus the room's media flag and the stage role,
    # which clients track live from room and role_change broadcasts. This is
    # the half that gets serialized, so neither re-enabling a room's media nor
    # a promotion needs the room re-serialized for each user.
    def eligible_to_publish_video_in_live_room?(room)
      live_media_entitlements(room)[:can_publish_video]
    end

    def eligible_to_screen_share_in_live_room?(room)
      live_media_entitlements(room)[:can_screen_share]
    end

    # Local recordings never touch the server; this only gates the control
    # and the roster flag that tells everyone else a recording is running.
    def can_record_live_locally?
      return false unless can_access_live?
      user.in_any_groups?(SiteSetting.live_local_recording_allowed_groups_map)
    end

    # Only stage-room listeners have anything to request — anyone who can
    # already speak (including admins and everyone in open rooms) cannot.
    def can_request_to_speak_in_live_room?(room)
      return false unless can_join_live_room?(room)
      room.stage? && !can_speak_in_live_room?(room)
    end

    def ensure_can_request_to_speak_in_live_room!(room)
      unless can_request_to_speak_in_live_room?(room)
        raise Discourse::InvalidAccess.new(I18n.t("live.errors.not_authorized"))
      end
    end

    private

    def live_media_entitlements(room)
      return Live::MediaEntitlements::NONE unless can_join_live_room?(room)

      Live::MediaEntitlements.for_user(user)
    end

    def live_room_media_live?(room)
      room.video_enabled? && can_speak_in_live_room?(room)
    end
  end
end
