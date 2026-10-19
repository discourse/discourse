# frozen_string_literal: true

module Voice
  # Delivers room invites: records them (so redeemed ones can award badges),
  # grants private-room invitees a membership, and notifies each invitee in
  # Discourse and via web push.
  class RoomInviter
    # An unredeemed invite can be re-sent once it is this old; anything more
    # frequent silently no-ops so repeat invites can't be used to spam
    # notifications at someone.
    RENOTIFY_AFTER = 1.day
    # Ephemeral rooms are live calls: a ring that went unanswered may be
    # retried once the previous ring has run out, but not while it is still
    # sounding on the callee's devices.
    RENOTIFY_EPHEMERAL_AFTER = 1.minute

    # How long clients ring for. Also stamped on the ring payload so a tab
    # waking up to a stale MessageBus backlog can discard expired rings.
    RING_SECONDS = 60

    def self.invite!(room:, inviter:, users:)
      users.filter_map { |user| new(room: room, inviter: inviter, user: user).invite! }
    end

    def initialize(room:, inviter:, user:)
      @room = room
      @inviter = inviter
      @user = user
    end

    def invite!
      return if @user.id == @inviter.id || @user.bot?
      return unless @user.guardian.can_access_voice?

      ensure_membership! unless @room.public?
      return unless @user.guardian.can_join_voice_room?(@room)

      invite =
        Voice::Invite.create_or_find_by(
          room_id: @room.id,
          user_id: @user.id,
          invited_by_id: @inviter.id,
        ) { |new_invite| new_invite.source = Voice::Invite::SOURCES[:notification] }

      # Reported as invited either way: an inviter must not be able to tell
      # they are muted, or probe how recently someone else already invited.
      notify!(invite) if should_notify?(invite)
      @user
    end

    private

    def should_notify?(invite)
      return false if notifications_blocked?
      return true if invite.previously_new_record?

      renotify_after = @room.ephemeral? ? RENOTIFY_EPHEMERAL_AFTER : RENOTIFY_AFTER
      invite.redeemed_at.nil? && invite.updated_at < renotify_after.ago
    end

    # Anyone the invitee could not receive a personal message from — muted,
    # ignored, or screened out by their personal message preferences — cannot
    # ring or notify them either.
    def notifications_blocked?
      UserCommScreener.new(
        acting_user: @inviter,
        target_user_ids: [@user.id],
      ).disallowing_pms_from_actor?(@user.id)
    end

    # The room page prompts for the invite to be redeemed on an actual join,
    # so notification clicks and shared links land on the same URL.
    def invite_path
      "/voice/r/#{@room.slug}/invited-by/#{@inviter.username_lower}"
    end

    def ensure_membership!
      @room
        .room_memberships
        .find_or_create_by!(user: @user) do |membership|
          membership.role = Voice::RoomMembership::ROLE_PARTICIPANT
        end
    end

    def notify!(invite)
      RateLimiter.new(
        @inviter,
        "voice-invites-daily",
        SiteSetting.voice_max_invites_per_day,
        1.day,
      ).performed!

      # Marks the re-notify window without disturbing redemption state.
      invite.touch unless invite.previously_new_record?

      # An invite into an ephemeral room is a call: the notification reads
      # "is calling you" and the client rings instead of just chiming.
      calling = @room.ephemeral?

      @user.notifications.create!(
        notification_type: Notification.types[:voice_invitation],
        high_priority: true,
        data: {
          room_id: @room.id,
          room_slug: @room.slug,
          room_name: @room.name,
          display_username: @inviter.username,
          call: calling || nil,
        }.compact.to_json,
      )

      i18n_scope = calling ? "voice.call_notification" : "voice.invite_notification"
      payload = nil
      I18n.with_locale(@user.effective_locale) do
        payload = {
          notification_type: Notification.types[:voice_invitation],
          username: @inviter.username,
          translated_title:
            I18n.t("#{i18n_scope}.title", username: @inviter.username, room_name: @room.name),
          excerpt: I18n.t("#{i18n_scope}.excerpt", room_name: @room.name),
          post_url: invite_path,
          tag: "#{Discourse.current_hostname}-voice-invite-#{@room.id}",
        }
      end

      MessageBus.publish("/notification-alert/#{@user.id}", payload, user_ids: [@user.id])
      PostAlerter.push_notification(@user, payload)

      ring! if calling
    end

    # Real-time ring for open clients. `sent_at` lets a tab that receives the
    # event late (MessageBus backlog after waking) drop rings that have
    # already run out instead of replaying them.
    def ring!
      notified_at = Time.current.to_i

      # A callee in do-not-disturb is not rung, but the caller still sees a
      # normal outgoing ring: the call simply goes unanswered, without
      # revealing the do-not-disturb status, and the missed-call notification
      # is waiting once it ends.
      ring_devices!(notified_at) unless @user.do_not_disturb?

      Voice::RoomBroadcaster.publish_ringing(@room, @user, notified_at: notified_at)
    end

    def ring_devices!(notified_at)
      MessageBus.publish(
        "/voice/call-ring/#{@user.id}",
        {
          room_id: @room.id,
          room_slug: @room.slug,
          room_name: @room.name,
          caller_username: @inviter.username,
          caller_name: @inviter.name,
          caller_avatar_template: @inviter.avatar_template,
          sent_at: notified_at,
          ring_seconds: RING_SECONDS,
        },
        user_ids: [@user.id],
      )
    end
  end
end
