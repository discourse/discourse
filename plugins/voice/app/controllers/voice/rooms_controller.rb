# frozen_string_literal: true

module Voice
  class RoomsController < ApplicationController
    # Signal budgets are accounted in relayed events (not HTTP requests), so a
    # legitimate full-room Trickle ICE burst — one offer plus batched
    # candidates to every peer, with headroom for an ICE restart — passes
    # while sustained signaling beyond it is rejected before any MessageBus
    # work happens.
    SIGNAL_REQUESTS_PER_USER = 30 # per 10 seconds
    SIGNAL_EVENTS_PER_USER_PER_MINUTE = 5_000
    SIGNAL_EVENTS_PER_ROOM_PER_MINUTE = 100_000

    STATE_FIELDS = %i[muted deafened video screen watching transcribing]

    # Anonymous visitors may browse the directory; the guardian still limits the
    # listing to public rooms, and only when access is open to everyone.
    skip_before_action :ensure_logged_in, only: :index

    before_action :load_room,
                  only: %i[
                    show
                    update
                    destroy
                    join
                    leave
                    participants
                    signal
                    chat_session
                    ensure_chat_session
                    chat_message
                    kick
                    flag
                    heartbeat
                    toggle_mute
                    state
                    livekit_token
                    start_recording
                    stop_recording
                    request_to_speak
                    withdraw_request_to_speak
                  ]

    def index
      Voice::DefaultRoomSeeder.ensure!

      # Capture before the room snapshot so a concurrent event is replayed rather than skipped.
      index_message_bus_last_id = MessageBus.last_id(Voice.room_index_channel)
      rooms =
        Voice::Room
          .visible_to(guardian)
          .includes(:room_memberships)
          .order(:created_at, :id)
          .select { |room| guardian.can_see_voice_room?(room) }
      directory_entries = Voice::RoomDirectoryPreloader.preload(rooms)
      chat_rooms =
        rooms.select do |room|
          entry = directory_entries[room.id]
          guardian.can_manage_voice_room?(room) ||
            entry&.participant_users&.any? { |participant| participant.id == current_user&.id }
        end
      chat_availability = rooms.to_h { |room| [room.id, false] }
      chat_availability.merge!(Voice::ChatSession.available_for_rooms(chat_rooms, guardian))

      render_json_dump(
        rooms:
          serialize_data(
            rooms,
            Voice::RoomSerializer,
            directory_entries: directory_entries,
            chat_availability: chat_availability,
          ),
        can_create_room: guardian.can_create_voice_room?,
        index_message_bus_last_id: index_message_bus_last_id,
      )
    end

    def show
      guardian.ensure_can_see_voice_room!(@room)
      render_serialized @room, Voice::RoomSerializer, root: :room, include_visit_count: true
    end

    def create
      guardian.ensure_can_create_voice_room!

      # Ephemeral rooms are created by features on the user's behalf (with
      # their own TTL-based cap), not by the user — they don't count here.
      if current_user.voice_rooms.persistent.count >= SiteSetting.voice_max_rooms_per_user
        raise Discourse::InvalidParameters.new(I18n.t("voice.errors.room_limit"))
      end

      room = Voice::Room.new(room_params)
      room.creator = current_user

      if room.save
        Voice::DirectoryBroadcaster.broadcast(action: :created, room: room)
        Voice::BadgeGranterHooks.on_room_create(current_user)
        render_serialized room, Voice::RoomSerializer, root: :room
      else
        render_json_error room
      end
    end

    def update
      guardian.ensure_can_manage_voice_room!(@room)

      name_changed = room_params[:name].present? && room_params[:name] != @room.name

      if @room.update(room_params)
        Voice::DirectoryBroadcaster.broadcast(action: :updated, room: @room)
        refresh_participant_statuses(@room) if name_changed
        render_serialized @room, Voice::RoomSerializer, root: :room
      else
        render_json_error @room
      end
    end

    def destroy
      guardian.ensure_can_manage_voice_room!(@room)
      # Built before the destroy so the broadcast still targets the members
      # whose memberships the destroy cascades away.
      broadcaster = Voice::DirectoryBroadcaster.new(@room, :destroyed)
      @room.destroy!
      broadcaster.broadcast
      Voice::Livekit::RoomServiceClient.delete_room(@room)
      Voice::ParticipantTracker.clear_transport_pin(@room.id)
      render json: success_json
    end

    def join
      guardian.ensure_can_join_voice_room!(@room)
      RateLimiter.new(current_user, "voice-joins", 30, 1.minute).performed!

      # A repeated join carrying the live participant session (a UI retry, a
      # duplicated request) refreshes the existing grant instead of re-running
      # join side effects: no session rotation, no second analytics session,
      # no badge/invite re-fires, no roster rebroadcast.
      if repeat_join?
        transport = Voice::ParticipantTracker.pinned_transport(@room.id) || "mesh"

        livekit = nil
        if transport == "livekit"
          livekit = mint_livekit_payload
          if livekit.nil?
            return(render_json_error(I18n.t("voice.errors.livekit_unavailable"), status: 503))
          end
        end

        Voice::ParticipantTracker.add(@room.id, current_user.id)
        Voice::ParticipantTracker.refresh_participant_session(@room.id, current_user.id)
        Voice::ParticipantTracker.refresh_transport_pin(@room.id)

        payload = {
          transport: transport,
          participant_session_id: params[:participant_session_id],
          ice: Voice::IceConfig.payload(current_user),
          room:
            Voice::RoomSerializer.new(
              @room,
              scope: guardian,
              root: false,
              include_visit_count: true,
            ).as_json,
        }
        payload[:livekit] = livekit if livekit
        return render json: payload
      end

      # Resolved before presence is added, so a LiveKit failure rejects the
      # join without leaving the user in the roster.
      transport = Voice::ParticipantTracker.pinned_transport(@room.id)
      transport ||= Voice::Livekit.available_for?(@room) ? "livekit" : "mesh"

      livekit = nil
      if transport == "livekit"
        livekit = mint_livekit_payload

        if livekit.nil?
          # Fall back to mesh only when explicitly enabled and the room is
          # empty — an occupied LiveKit room must never be split, and silent
          # degradation hides outages from ops.
          if SiteSetting.voice_livekit_mesh_fallback &&
               Voice::ParticipantTracker.user_ids(@room.id).empty?
            Voice::ParticipantTracker.clear_transport_pin(@room.id)
            transport = "mesh"
          else
            return(render_json_error(I18n.t("voice.errors.livekit_unavailable"), status: 503))
          end
        end
      end

      transport = Voice::ParticipantTracker.pin_transport!(@room.id, transport)

      # A concurrent first join can win the pin race with a different
      # transport (e.g. settings changed between the two resolutions) —
      # the pin is authoritative.
      if transport == "livekit" && livekit.nil?
        livekit = mint_livekit_payload
        if livekit.nil?
          return(render_json_error(I18n.t("voice.errors.livekit_unavailable"), status: 503))
        end
      end
      livekit = nil if transport == "mesh"

      Voice::ParticipantTracker.clear_left(@room.id, current_user.id)

      admission =
        Voice::ParticipantTracker.add_within_capacity(
          @room.id,
          current_user.id,
          @room.effective_max_participants,
        )
      return render_json_error(I18n.t("voice.errors.room_full"), status: 422) if admission == :full

      # A joiner already in the roster but without the live session proof (a
      # reloaded tab, a second device — or a client replaying this endpoint)
      # takes over the existing grant rather than re-running first-join side
      # effects: the session still rotates so the new tab gains signaling
      # authority, but the open analytics row is reused and badge/invite
      # hooks don't re-fire. Otherwise every replayed join is a free
      # analytics insert and roster broadcast.
      takeover = admission == :existing
      previous_metadata =
        (
          if takeover
            Voice::ParticipantTracker.get_metadata(@room.id, current_user.id)
          else
            {}
          end
        )

      participant_session_id =
        Voice::ParticipantTracker.create_participant_session!(@room.id, current_user.id)

      membership = @room.room_memberships.find_by(user_id: current_user.id)
      role = membership&.role_name || "participant"
      metadata = { role: role, last_heartbeat_at: Time.now.to_f }

      if SiteSetting.voice_analytics_enabled
        session = nil
        if previous_metadata[:session_id]
          session =
            Voice::Session.find_by(
              id: previous_metadata[:session_id],
              user_id: current_user.id,
              room_id: @room.id,
              left_at: nil,
            )
        end
        session ||= Voice::Session.create!(user: current_user, room: @room, joined_at: Time.current)
        metadata[:session_id] = session.id
      end

      metadata[:skip_status] = true if params[:skip_status].present?
      Voice::ParticipantTracker.update_metadata(@room.id, current_user.id, metadata)

      if takeover
        Voice::RoomBroadcaster.publish_participants_if_changed(@room)
      else
        Voice::RoomBroadcaster.publish_participants(@room)

        participants = Voice::ParticipantTracker.list(@room.id)
        Voice::BadgeGranterHooks.on_join(current_user, @room, participants)

        if params[:invited_by].present?
          invite =
            Voice::Invite.redeem!(
              room: @room,
              user: current_user,
              inviter_username: params[:invited_by],
            )
          Voice::BadgeGranterHooks.on_invite_redeemed(invite) if invite
        end
      end

      # A join settles this room's pending invitation/call notifications: the
      # incoming-call modal, push notifications, and cached-room transitions
      # never pass through the user-menu click marking, so without this the
      # notification stays unread forever.
      mark_invitation_notifications_read!

      Voice::UserStatusManager.set_voice_status(current_user, @room) if params[:skip_status].blank?

      payload = {
        transport: transport,
        participant_session_id: participant_session_id,
        ice: Voice::IceConfig.payload(current_user),
        room:
          Voice::RoomSerializer.new(
            @room,
            scope: guardian,
            root: false,
            include_visit_count: true,
          ).as_json,
      }
      payload[:livekit] = livekit if livekit
      render json: payload
    end

    # Reissues a LiveKit access token for the reconnect ladder, which runs
    # precisely when the presence TTL may have lapsed — so this endpoint
    # re-adds presence itself (same authz as heartbeat) instead of requiring
    # it. 410 tells the client the room instance ended: stop the ladder,
    # tear down locally, and offer a rejoin.
    def livekit_token
      guardian.ensure_can_join_voice_room!(@room)
      RateLimiter.new(current_user, "voice-livekit-token", 10, 1.minute).performed!

      if Voice::ParticipantTracker.pinned_transport(@room.id) != "livekit"
        return(render_json_error(I18n.t("voice.errors.livekit_room_instance_ended"), status: 410))
      end

      # The reconnect ladder only runs while the client considers itself in the
      # call, so an explicit token request voids any leave/kick tombstone.
      Voice::ParticipantTracker.clear_left(@room.id, current_user.id)
      Voice::ParticipantTracker.add(@room.id, current_user.id)
      # The session may have expired along with the lapsed presence — mint a
      # fresh one so heartbeat/state keep working after the reconnect.
      participant_session_id =
        Voice::ParticipantTracker.create_participant_session!(@room.id, current_user.id)
      metadata = Voice::ParticipantTracker.get_metadata(@room.id, current_user.id)
      metadata[:last_heartbeat_at] = Time.now.to_f
      Voice::ParticipantTracker.update_metadata(@room.id, current_user.id, metadata)
      Voice::ParticipantTracker.refresh_transport_pin(@room.id)
      Voice::RoomBroadcaster.publish_participants_if_changed(@room)

      livekit = mint_livekit_payload
      if livekit.nil?
        return(render_json_error(I18n.t("voice.errors.livekit_unavailable"), status: 503))
      end

      render json: livekit.merge(participant_session_id: participant_session_id)
    end

    def start_recording
      guardian.ensure_can_manage_voice_room!(@room)
      render json: { recording: Voice::RecordingManager.start!(@room, current_user) }
    rescue Voice::RecordingManager::Error => e
      render_json_error(e.message, status: 422)
    end

    def stop_recording
      guardian.ensure_can_manage_voice_room!(@room)
      Voice::RecordingManager.stop!(@room)
      head :no_content
    rescue Voice::RecordingManager::Error => e
      render_json_error(e.message, status: 422)
    end

    def leave
      guardian.ensure_can_join_voice_room!(@room)

      # A leave from a stale tab — carrying a participant session that a newer
      # join has since superseded — must not tear down the presence and
      # session the newer tab now owns.
      if params[:participant_session_id].present? &&
           !Voice::ParticipantTracker.valid_participant_session?(
             @room.id,
             current_user.id,
             params[:participant_session_id],
           )
        return head :no_content
      end

      session = close_session_for(@room.id, current_user.id)
      Voice::ParticipantTracker.mark_left(@room.id, current_user.id)
      Voice::ParticipantTracker.remove(@room.id, current_user.id)
      if Voice::ParticipantTracker.user_ids(@room.id).empty?
        Voice::Livekit::RoomServiceClient.delete_room(@room)
        Voice::ParticipantTracker.clear_transport_pin(@room.id)
      end
      Voice::UserStatusManager.clear_voice_status(current_user)
      Voice::RoomBroadcaster.publish_participants(@room)
      Voice::BadgeGranterHooks.on_leave(current_user, session)
      head :no_content
    end

    def heartbeat
      guardian.ensure_can_join_voice_room!(@room)

      # A beat already in flight when the user left (or was kicked) must not
      # resurrect their presence; only join/livekit_token re-establish it.
      return head :no_content if Voice::ParticipantTracker.recently_left?(@room.id, current_user.id)

      ensure_participant_session!

      Voice::ParticipantTracker.add(@room.id, current_user.id)
      Voice::ParticipantTracker.refresh_participant_session(@room.id, current_user.id)

      metadata = Voice::ParticipantTracker.get_metadata(@room.id, current_user.id)
      metadata[:last_heartbeat_at] = Time.now.to_f

      if params.key?(:idle_state)
        idle_state = params[:idle_state].to_s
        metadata[:idle_state] = idle_state if %w[active idle afk].include?(idle_state)
      end

      Voice::ParticipantTracker.update_metadata(@room.id, current_user.id, metadata)
      Voice::ParticipantTracker.refresh_transport_pin(@room.id)

      # Keep an in-progress chat session alive while someone is present, so it
      # only rolls over to a new thread once the room is idle AND empty.
      Voice::ChatSession.touch!(@room)

      # Detect and broadcast any drift (idle change, or a participant whose TTL
      # lapsed after an abrupt disconnect) now that metadata is persisted.
      Voice::RoomBroadcaster.publish_participants_if_changed(@room)

      if !metadata[:skip_status] && Voice::UserStatusManager.voice_status_active?(current_user)
        if metadata[:idle_state] == "afk"
          Voice::UserStatusManager.set_afk_status(current_user, @room)
        else
          Voice::UserStatusManager.set_voice_status(current_user, @room)
        end
      end

      head :no_content
    end

    def participants
      guardian.ensure_can_join_voice_room!(@room)
      all_metadata = Voice::ParticipantTracker.get_all_metadata(@room.id)
      render json: {
               participants:
                 Voice::ParticipantTracker
                   .list(@room.id)
                   .map do |user|
                     BasicUserSerializer
                       .new(user, scope: guardian, root: false)
                       .as_json
                       .merge(all_metadata[user.id] || {})
                   end,
             }
    end

    def state
      guardian.ensure_can_join_voice_room!(@room)
      ensure_participant_session!
      RateLimiter.new(current_user, "voice-room-state", 40, 10.seconds).performed!

      if STATE_FIELDS.none? { |field| params.key?(field) }
        raise Discourse::InvalidParameters.new(I18n.t("voice.errors.state_change_required"))
      end

      bool = ActiveModel::Type::Boolean.new
      wants_unmute = params.key?(:muted) && !bool.cast(params[:muted])

      if wants_unmute && @room.stage? && !guardian.can_speak_in_voice_room?(@room)
        raise Discourse::InvalidAccess.new(I18n.t("voice.errors.listeners_cannot_unmute"))
      end

      wants_camera = params.key?(:video) && bool.cast(params[:video])
      wants_screen = params.key?(:screen) && bool.cast(params[:screen])

      if wants_camera || wants_screen
        unless @room.video_allowed? && guardian.can_speak_in_voice_room?(@room)
          raise Discourse::InvalidAccess.new(I18n.t("voice.errors.video_not_allowed"))
        end

        if video_publisher_count(@room, exclude_user_id: current_user.id) >=
             SiteSetting.voice_video_max_publishers
          raise Discourse::InvalidParameters.new(I18n.t("voice.errors.video_publisher_limit"))
        end
      end

      metadata = Voice::ParticipantTracker.get_metadata(@room.id, current_user.id)
      previous_metadata = metadata.dup
      metadata[:is_muted] = bool.cast(params[:muted]) if params.key?(:muted)
      metadata[:is_deafened] = bool.cast(params[:deafened]) if params.key?(:deafened)
      metadata[:is_video_on] = bool.cast(params[:video]) if params.key?(:video)
      metadata[:is_screen_sharing] = bool.cast(params[:screen]) if params.key?(:screen)
      metadata[:watching_video] = bool.cast(params[:watching]) if params.key?(:watching)
      metadata[:is_transcribing] = bool.cast(params[:transcribing]) if params.key?(:transcribing)

      # A request that changes nothing must not become a full-roster
      # rebroadcast to every participant.
      return head :no_content if metadata == previous_metadata

      Voice::ParticipantTracker.update_metadata(@room.id, current_user.id, metadata)

      Voice::RoomBroadcaster.publish_participants(@room)

      head :no_content
    end

    alias toggle_mute state

    def kick
      guardian.ensure_can_manage_voice_room!(@room)

      user_id = params.require(:user_id).to_i

      if user_id == current_user.id
        raise Discourse::InvalidParameters.new(I18n.t("voice.errors.cannot_kick_self"))
      end

      if user_id == @room.creator_id
        raise Discourse::InvalidParameters.new(I18n.t("voice.errors.cannot_kick_creator"))
      end

      session = close_session_for(@room.id, user_id)
      Voice::ParticipantTracker.mark_left(@room.id, user_id)
      Voice::ParticipantTracker.remove(@room.id, user_id)

      kicked_user = User.find_by(id: user_id)
      Voice::UserStatusManager.clear_voice_status(kicked_user) if kicked_user

      Voice::BadgeGranterHooks.on_leave(kicked_user, session) if kicked_user
      Voice::RoomBroadcaster.publish_kick(@room, user_id)
      Voice::RoomBroadcaster.publish_participants(@room)

      # The client-side kicked handler already forces a clean leave; this
      # additionally evicts the media session from the SFU.
      Voice::Livekit::RoomServiceClient.remove_participant(@room, user_id)

      head :no_content
    end

    def flag
      RateLimiter.new(current_user, "flag_voice_user", 4, 1.minute).performed!

      permitted = params.permit(:user_id, :flag_type_id, :message)

      target_user = User.find_by(id: permitted[:user_id].to_i)
      raise Discourse::InvalidParameters.new(:user_id) if target_user.blank?

      # A room participant carries no implied context the way a post or chat
      # message does, so the free-form notify_moderators flag is the only one
      # that can be raised here.
      if permitted[:flag_type_id].to_i != ReviewableScore.types[:notify_moderators]
        raise Discourse::InvalidParameters.new(:flag_type_id)
      end

      raise Discourse::InvalidParameters.new(:message) if permitted[:message].blank?

      result =
        Voice::ReviewQueue.new.flag_user(
          @room,
          target_user,
          guardian,
          permitted[:flag_type_id].to_i,
          message: permitted[:message],
        )

      if result[:success]
        render json: success_json
      else
        render_json_error(result[:errors])
      end
    end

    def request_to_speak
      guardian.ensure_can_request_to_speak_in_voice_room!(@room)
      # The session (not the eventually-consistent roster) is what proves the
      # user is actually in the call.
      ensure_participant_session!

      if Voice::ParticipantTracker.raise_hand(@room.id, current_user.id)
        raised_at =
          Voice::ParticipantTracker.get_metadata(@room.id, current_user.id)[:hand_raised_at]
        Voice::RoomBroadcaster.publish_hand_raise(
          @room,
          current_user.id,
          raised: true,
          raised_at: raised_at,
          reason: "raised",
        )
        Voice::RoomBroadcaster.publish_participants(@room)
      end

      head :no_content
    end

    def withdraw_request_to_speak
      target_id = params[:user_id].present? ? params[:user_id].to_i : current_user.id

      if target_id == current_user.id
        guardian.ensure_can_join_voice_room!(@room)
        ensure_participant_session!
      else
        # A moderator dismissing someone else's raised hand is a management
        # action and must not require the moderator to be in the call.
        guardian.ensure_can_manage_voice_room!(@room)
      end

      if Voice::ParticipantTracker.lower_hand(@room.id, target_id)
        reason = target_id == current_user.id ? "withdrawn" : "dismissed"
        Voice::RoomBroadcaster.publish_hand_raise(@room, target_id, raised: false, reason: reason)
        Voice::RoomBroadcaster.publish_participants(@room)
      end

      head :no_content
    end

    def signal
      guardian.ensure_can_join_voice_room!(@room)
      # Room eligibility alone is not enough: signaling authority comes from
      # the server-attested session minted by join, so an eligible user who
      # never joined can't reach anyone's media stack.
      ensure_participant_session!

      RateLimiter.new(
        current_user,
        "voice-signals",
        SIGNAL_REQUESTS_PER_USER,
        10.seconds,
      ).performed!

      # Defense in depth: LiveKit rooms never exchange WebRTC signals.
      if Voice::ParticipantTracker.pinned_transport(@room.id) == "livekit"
        return(render_json_error(I18n.t("voice.errors.livekit_no_signaling"), status: 422))
      end

      raw_payload = params[:payload]
      raw_payload = raw_payload.to_unsafe_h if raw_payload.respond_to?(:to_unsafe_h)
      if raw_payload.blank?
        raise Discourse::InvalidParameters.new(I18n.t("voice.errors.missing_payload"))
      end

      messages = Voice::SignalValidator.parse!(raw_payload, room: @room)
      if messages.blank?
        raise Discourse::InvalidParameters.new(I18n.t("voice.errors.missing_payload"))
      end

      total_events = messages.sum { |message| message[:events].size }
      Voice::ControlPlaneLimiter.perform!(
        "signal-events:user:#{current_user.id}",
        limit: SIGNAL_EVENTS_PER_USER_PER_MINUTE,
        period: 1.minute,
        weight: total_events,
      )
      Voice::ControlPlaneLimiter.perform!(
        "signal-events:room:#{@room.id}",
        limit: SIGNAL_EVENTS_PER_ROOM_PER_MINUTE,
        period: 1.minute,
        weight: total_events,
      )

      relay = Voice::SignalRelay.new(@room)
      messages.each do |message|
        relay.publish!(
          from: current_user,
          recipient_id: message[:recipient_id],
          events: message[:events],
        )
      end

      head :no_content
    end

    # Returns the room's current live chat session (linked channel and active
    # thread) so the panel can render it. Does not create or change anything.
    def chat_session
      ensure_chat_available!
      render json: Voice::ChatSession.state(@room)
    end

    # Prepares the room's chat session for the caller: rolls a stale session
    # over and follows them on the linked channel so chat's own message
    # endpoints accept their posts. Never creates a thread — that only happens
    # with the session's first message (see #chat_message); every later message
    # goes through chat's regular API, not through Voice.
    def ensure_chat_session
      ensure_chat_available!
      render json: Voice::ChatSession.start!(@room, current_user)
    end

    # Posts the session's opening message, creating the thread it roots. Only
    # called by a panel that sees no live thread; once one exists, messages go
    # through chat's own API instead.
    def chat_message
      ensure_chat_available!

      text = params.require(:message).to_s
      # We post through Chat::CreateMessage directly, which bypasses the
      # per-user flood limit + auto-silence that chat enforces in its own
      # controller — apply it here so this endpoint isn't a way around it.
      ::Chat::MessageRateLimiter.run!(current_user)
      render json: Voice::ChatSession.post_message!(@room, current_user, text)
    rescue Voice::ChatSession::Error => e
      # The chat plugin rejected the message for a reason worth showing (a
      # duplicate, a too-long message, threading disabled, …) — surface it
      # instead of the generic 403 that an access error would produce.
      render_json_error(e.message, status: 422)
    end

    private

    def ensure_participant_session!
      if Voice::ParticipantTracker.valid_participant_session?(
           @room.id,
           current_user.id,
           params[:participant_session_id],
         )
        return
      end

      # Sustained probing with a missing or stale session is cut off before it
      # can accumulate into free Redis/roster work.
      RateLimiter.new(current_user, "voice-session-denied", 30, 1.minute).performed!

      raise Discourse::InvalidAccess.new(
              :voice_participant_session_required,
              nil,
              custom_message: "voice.errors.participant_session_required",
            )
    end

    def repeat_join?
      params[:participant_session_id].present? &&
        Voice::ParticipantTracker.valid_participant_session?(
          @room.id,
          current_user.id,
          params[:participant_session_id],
        ) && Voice::ParticipantTracker.user_ids(@room.id).include?(current_user.id)
    end

    def mark_invitation_notifications_read!
      notification_ids =
        current_user
          .notifications
          .where(notification_type: Notification.types[:voice_invitation], read: false)
          .select { |notification| notification.data_hash[:room_id] == @room.id }
          .map(&:id)
      return if notification_ids.empty?

      Notification.read(current_user, notification_ids)
      current_user.publish_notifications_state
    end

    # Broad rescue is deliberate: a LiveKit problem must surface as the 503
    # handled by the callers, never as an opaque 500.
    def mint_livekit_payload
      token = Voice::Livekit.mint_token(user: current_user, room: @room, guardian: guardian)
      { url: SiteSetting.voice_livekit_url, token: token }
    rescue StandardError => e
      Rails.logger.error(
        "[voice-livekit] token mint failed for room #{@room.id}: #{e.class} #{e.message}",
      )
      nil
    end

    def ensure_chat_available!
      guardian.ensure_can_join_voice_room!(@room)
      unless Voice::ChatSession.available_for?(@room, guardian)
        raise Discourse::InvalidAccess.new(
                :voice_chat_unavailable,
                nil,
                custom_message: "voice.errors.chat_unavailable",
              )
      end
      if Voice::ParticipantTracker.user_ids(@room.id).exclude?(current_user.id)
        raise Discourse::InvalidAccess.new(
                :voice_chat_requires_presence,
                nil,
                custom_message: "voice.errors.chat_requires_presence",
              )
      end
    end

    def refresh_participant_statuses(room)
      Voice::ParticipantTracker
        .user_ids(room.id)
        .each do |uid|
          user = User.find_by(id: uid)
          next unless user
          next unless Voice::UserStatusManager.voice_status_active?(user)
          Voice::UserStatusManager.set_voice_status(user, room)
        end
    end

    def close_session_for(room_id, user_id)
      metadata = Voice::ParticipantTracker.get_metadata(room_id, user_id)
      return unless metadata[:session_id]

      session = Voice::Session.find_by(id: metadata[:session_id])
      session&.close!
      session
    end

    def video_publisher_count(room, exclude_user_id: nil)
      active_ids = Voice::ParticipantTracker.user_ids(room.id)
      all_metadata = Voice::ParticipantTracker.get_all_metadata(room.id)

      active_ids.count do |user_id|
        next false if user_id == exclude_user_id
        metadata = all_metadata[user_id] || {}
        metadata[:is_video_on] || metadata[:is_screen_sharing]
      end
    end

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

    def load_room
      @room =
        Voice::Room.find_by(id: params[:id]) ||
          Voice::Room.find_by!(slug: params[:id] || params[:slug])
    end
  end
end
