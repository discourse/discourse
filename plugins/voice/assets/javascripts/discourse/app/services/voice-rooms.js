import { tracked } from "@glimmer/tracking";
import Service, { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { bind } from "discourse/lib/decorators";

// Directory broadcasts are serialized without a user, so fields the server
// gates per user (chat availability, manager-only chat settings) are absent
// from them. A broadcast replaces the whole room object; carry over what this
// client already knows so a mid-call room update doesn't wipe its own state.
const USER_GATED_ROOM_FIELDS = [
  "chat_available",
  "chat_channel_id",
  "chat_idle_minutes",
];

// Participant broadcasts arrive in arbitrary database order, so every list
// that reaches the UI is normalized to one canonical order — otherwise
// sidebar rows and video tiles reshuffle on each broadcast.
function sortParticipants(participants) {
  return [...(participants || [])].sort((a, b) => {
    const nameA = (a?.username || "").toLowerCase();
    const nameB = (b?.username || "").toLowerCase();
    if (nameA !== nameB) {
      return nameA < nameB ? -1 : 1;
    }
    return Number(a?.id) - Number(b?.id);
  });
}

// Speaking flips several times per utterance, so it lives outside the room
// payloads: mutating one tracked flag re-renders only the bindings that read
// it, instead of invalidating `rooms` and rebuilding every sidebar link and
// tile on each flip.
class ParticipantSpeakingState {
  @tracked speaking = false;
}

export default class VoiceRoomsService extends Service {
  @service currentUser;
  @service messageBus;
  @service siteSettings;
  @service site;

  @tracked rooms = [];
  @tracked canCreateRoom = false;

  #roomsById = new Map();
  #roomsBySlug = new Map();
  #roomSubscriptions = new Map();
  #roomHandlers = new Map();
  #speakingByKey = new Map();

  constructor() {
    super(...arguments);
    if (!this.siteSettings.voice_enabled) {
      return;
    }

    // Anonymous visitors only bootstrap when Voice is open to everyone; the
    // server then returns just the public rooms.
    if (!this.currentUser && !this.site.voice_public_access) {
      return;
    }

    this.ready = this.#bootstrap();
  }

  willDestroy() {
    super.willDestroy(...arguments);
    this.messageBus.unsubscribe(
      "/voice/rooms/index",
      this.handleDirectoryEvent
    );
    this.#roomSubscriptions.forEach((callback, roomId) => {
      this.messageBus.unsubscribe(`/voice/rooms/${roomId}`, callback);
    });
    this.#roomSubscriptions.clear();
    this.#roomHandlers.clear();
  }

  roomById(id) {
    return this.#roomsById.get(id);
  }

  roomBySlug(slug) {
    return this.#roomsBySlug.get(slug);
  }

  // Replaces (or adds) a room from a fresh payload — a directory broadcast or
  // an endpoint response like join's, whose serialization is scoped to the
  // current user and so carries the per-user chat fields.
  upsertRoom(room) {
    room.active_participants = sortParticipants(room.active_participants);

    const previous = this.#roomsById.get(room.id);
    if (previous) {
      USER_GATED_ROOM_FIELDS.forEach((field) => {
        if (room[field] === undefined) {
          room[field] = previous[field];
        }
      });
    }

    this.#roomsById.set(room.id, room);
    this.#roomsBySlug.set(room.slug, room);
    this.#ensureRoomSubscription(room.id, room.message_bus_last_id);
    this.rooms = Array.from(this.#roomsById.values());
  }

  @bind
  handleDirectoryEvent(message) {
    if (message.type === "destroyed") {
      this.#roomsById.delete(message.room.id);
      this.#roomsBySlug.delete(message.room.slug);
      this.#teardownRoomSubscription(message.room.id);
    } else {
      this.upsertRoom(message.room);
    }

    this.rooms = Array.from(this.#roomsById.values());

    if (message.type === "updated") {
      this.#forwardToRoomHandlers(message.room.id, {
        type: "room_updated",
        room_id: message.room.id,
        room: message.room,
      });
    }
  }

  registerRoomHandler(roomId, callback) {
    let handlers = this.#roomHandlers.get(roomId);
    if (!handlers) {
      handlers = new Set();
      this.#roomHandlers.set(roomId, handlers);
    }
    handlers.add(callback);
  }

  unregisterRoomHandler(roomId, callback) {
    const handlers = this.#roomHandlers.get(roomId);
    if (!handlers) {
      return;
    }
    handlers.delete(callback);
    if (handlers.size === 0) {
      this.#roomHandlers.delete(roomId);
    }
  }

  handleRoomBroadcast(payload) {
    const room = this.#roomsById.get(payload.room_id);
    if (!room) {
      return;
    }

    if (payload.type === "participants") {
      this.#setRoomParticipants(room.id, payload.participants || []);
    } else if (payload.type === "role_change") {
      this.setParticipantRole(payload.room_id, payload.user_id, payload.role);
    } else if (payload.type === "hand_raise") {
      this.setParticipantHandRaised(
        payload.room_id,
        payload.user_id,
        payload.raised ? payload.raised_at : null
      );
    } else if (payload.type === "recording") {
      this.setRoomRecording(payload.room_id, payload.recording);
    } else if (payload.type === "ringing") {
      this.#addRinging(payload.room_id, payload.user, payload.notified_at);
    }

    this.#forwardToRoomHandlers(payload.room_id, payload);
  }

  setRoomRecording(roomId, recording) {
    const room = this.#roomsById.get(roomId);
    if (!room) {
      return;
    }

    room.recording = recording ?? null;
    this.rooms = [...this.rooms];
  }

  addParticipant(roomId, participant) {
    if (!participant?.id) {
      return;
    }

    const room = this.#roomsById.get(roomId);
    if (!room) {
      return;
    }

    const existing = room.active_participants || [];
    if (existing.some((p) => p?.id === participant.id)) {
      return;
    }

    room.active_participants = sortParticipants([...existing, participant]);
    this.rooms = [...this.rooms];
  }

  removeParticipant(roomId, userId) {
    const targetId = Number(userId);
    if (!targetId) {
      return;
    }

    const room = this.#roomsById.get(roomId);
    if (!room || !Array.isArray(room.active_participants)) {
      return;
    }

    const filtered = room.active_participants.filter(
      (participant) => Number(participant?.id) !== targetId
    );

    if (filtered.length === room.active_participants.length) {
      return;
    }

    room.active_participants = filtered;
    this.setParticipantSpeaking(roomId, targetId, false);
    this.rooms = [...this.rooms];
  }

  isParticipantSpeaking(roomId, userId) {
    return this.#speakingState(roomId, userId).speaking;
  }

  setParticipantSpeaking(roomId, userId, speaking) {
    const state = this.#speakingState(roomId, userId);
    if (state.speaking !== !!speaking) {
      state.speaking = !!speaking;
    }
  }

  setParticipantMuted(roomId, userId, muted) {
    const targetId = Number(userId);
    if (!targetId) {
      return;
    }

    const room = this.#roomsById.get(roomId);
    if (!room || !Array.isArray(room.active_participants)) {
      return;
    }

    let changed = false;
    room.active_participants = room.active_participants.map((participant) => {
      const participantId = Number(participant?.id);
      if (!participantId || participantId !== targetId) {
        return participant;
      }

      if (!!participant.is_muted === muted) {
        return participant;
      }

      changed = true;
      return {
        ...participant,
        is_muted: muted,
      };
    });

    if (changed) {
      this.rooms = [...this.rooms];
    }
  }

  setParticipantIdleState(roomId, userId, idleState) {
    const targetId = Number(userId);
    if (!targetId) {
      return;
    }

    const room = this.#roomsById.get(roomId);
    if (!room || !Array.isArray(room.active_participants)) {
      return;
    }

    let changed = false;
    room.active_participants = room.active_participants.map((participant) => {
      const participantId = Number(participant?.id);
      if (!participantId || participantId !== targetId) {
        return participant;
      }

      if (participant.idle_state === idleState) {
        return participant;
      }

      changed = true;
      return {
        ...participant,
        idle_state: idleState,
      };
    });

    if (changed) {
      this.rooms = [...this.rooms];
    }
  }

  setParticipantVideoState(roomId, userId, fields) {
    const targetId = Number(userId);
    if (!targetId || !fields) {
      return;
    }

    const room = this.#roomsById.get(roomId);
    if (!room || !Array.isArray(room.active_participants)) {
      return;
    }

    let changed = false;
    room.active_participants = room.active_participants.map((participant) => {
      const participantId = Number(participant?.id);
      if (!participantId || participantId !== targetId) {
        return participant;
      }

      const unchanged = Object.entries(fields).every(
        ([key, value]) => !!participant[key] === !!value
      );
      if (unchanged) {
        return participant;
      }

      changed = true;
      return {
        ...participant,
        ...fields,
      };
    });

    if (changed) {
      this.rooms = [...this.rooms];
    }
  }

  setParticipantRole(roomId, userId, role) {
    const targetId = Number(userId);
    if (!targetId) {
      return;
    }

    const room = this.#roomsById.get(roomId);
    if (!room || !Array.isArray(room.active_participants)) {
      return;
    }

    let changed = false;
    room.active_participants = room.active_participants.map((participant) => {
      const participantId = Number(participant?.id);
      if (!participantId || participantId !== targetId) {
        return participant;
      }

      if (participant.role === role) {
        return participant;
      }

      changed = true;
      return {
        ...participant,
        role,
      };
    });

    if (changed) {
      this.rooms = [...this.rooms];
    }
  }

  setParticipantHandRaised(roomId, userId, raisedAt) {
    const targetId = Number(userId);
    if (!targetId) {
      return;
    }

    const room = this.#roomsById.get(roomId);
    if (!room || !Array.isArray(room.active_participants)) {
      return;
    }

    let changed = false;
    room.active_participants = room.active_participants.map((participant) => {
      const participantId = Number(participant?.id);
      if (!participantId || participantId !== targetId) {
        return participant;
      }

      if ((participant.hand_raised_at ?? null) === (raisedAt ?? null)) {
        return participant;
      }

      changed = true;
      const updated = { ...participant };
      if (raisedAt) {
        updated.hand_raised_at = raisedAt;
      } else {
        delete updated.hand_raised_at;
      }
      return updated;
    });

    if (changed) {
      this.rooms = [...this.rooms];
    }
  }

  setParticipantDeafened(roomId, userId, deafened) {
    const targetId = Number(userId);
    if (!targetId) {
      return;
    }

    const room = this.#roomsById.get(roomId);
    if (!room || !Array.isArray(room.active_participants)) {
      return;
    }

    let changed = false;
    room.active_participants = room.active_participants.map((participant) => {
      const participantId = Number(participant?.id);
      if (!participantId || participantId !== targetId) {
        return participant;
      }

      if (!!participant.is_deafened === deafened) {
        return participant;
      }

      changed = true;
      return {
        ...participant,
        is_deafened: deafened,
      };
    });

    if (changed) {
      this.rooms = [...this.rooms];
    }
  }

  async #bootstrap() {
    const payload = await ajax("/voice/rooms.json");
    this.canCreateRoom = payload.can_create_room ?? false;
    this.#hydrateRooms(payload.rooms);

    // Subscribing from the snapshot's message-bus position replays anything
    // published while the payload was in flight; subscribing without one
    // would silently drop those events.
    this.messageBus.subscribe(
      "/voice/rooms/index",
      this.handleDirectoryEvent,
      payload.index_message_bus_last_id ?? -1
    );

    return this.rooms;
  }

  #hydrateRooms(roomPayloads) {
    this.rooms = roomPayloads;
    this.#roomsById.clear();
    this.#roomsBySlug.clear();

    roomPayloads.forEach((room) => {
      room.active_participants = sortParticipants(room.active_participants);
      this.#roomsById.set(room.id, room);
      this.#roomsBySlug.set(room.slug, room);
      this.#ensureRoomSubscription(room.id, room.message_bus_last_id);
    });
  }

  #ensureRoomSubscription(roomId, lastId) {
    if (this.#roomSubscriptions.has(roomId)) {
      return;
    }

    const channel = `/voice/rooms/${roomId}`;
    const callback = (message) => this.handleRoomBroadcast(message);
    this.messageBus.subscribe(channel, callback, lastId ?? -1);
    this.#roomSubscriptions.set(roomId, callback);
  }

  #teardownRoomSubscription(roomId) {
    const callback = this.#roomSubscriptions.get(roomId);
    if (callback) {
      const channel = `/voice/rooms/${roomId}`;
      this.messageBus.unsubscribe(channel, callback);
      this.#roomSubscriptions.delete(roomId);
    }
    this.#roomHandlers.delete(roomId);
  }

  #forwardToRoomHandlers(roomId, payload) {
    const handlers = this.#roomHandlers.get(roomId);
    if (!handlers) {
      return;
    }
    handlers.forEach((callback) => callback(payload));
  }

  // Someone in an ephemeral call room started ringing `user` — record it so
  // the room page can show a pending tile. A repeat ring for the same user
  // replaces their entry, restarting the ring window. Entries are never
  // pruned here; the display filters out present users and expired rings.
  #addRinging(roomId, user, notifiedAt) {
    const room = this.#roomsById.get(roomId);
    if (!room || !user?.id) {
      return;
    }

    const others = (room.ringing || []).filter(
      (entry) => Number(entry.user?.id) !== Number(user.id)
    );
    room.ringing = [...others, { user, notified_at: notifiedAt }];
    this.rooms = [...this.rooms];
  }

  #speakingState(roomId, userId) {
    const key = `${roomId}:${Number(userId)}`;
    let state = this.#speakingByKey.get(key);
    if (!state) {
      state = new ParticipantSpeakingState();
      this.#speakingByKey.set(key, state);
    }
    return state;
  }

  #setRoomParticipants(roomId, participants) {
    const room = this.#roomsById.get(roomId);
    if (!room) {
      return;
    }

    const previous = room.active_participants || [];
    const stateByUserId = new Map(
      previous
        .filter((participant) => Number(participant?.id))
        .map((participant) => [
          Number(participant.id),
          {
            is_muted: participant.is_muted === true,
            is_deafened: participant.is_deafened === true,
            is_video_on: participant.is_video_on === true,
            is_screen_sharing: participant.is_screen_sharing === true,
            watching_video: participant.watching_video === true,
            idle_state: participant.idle_state,
          },
        ])
    );

    const merged = (participants || []).map((participant) => {
      const participantId = Number(participant?.id);
      const previousState = stateByUserId.get(participantId);
      if (!participantId || !previousState) {
        return participant;
      }

      return {
        ...participant,
        is_muted: participant.is_muted ?? previousState.is_muted,
        is_deafened: participant.is_deafened ?? previousState.is_deafened,
        is_video_on: participant.is_video_on ?? previousState.is_video_on,
        is_screen_sharing:
          participant.is_screen_sharing ?? previousState.is_screen_sharing,
        watching_video:
          participant.watching_video ?? previousState.watching_video,
        idle_state: participant.idle_state ?? previousState.idle_state,
      };
    });
    const mergedIds = new Set(merged.map((p) => Number(p?.id)));
    previous.forEach((participant) => {
      const participantId = Number(participant?.id);
      if (participantId && !mergedIds.has(participantId)) {
        this.setParticipantSpeaking(roomId, participantId, false);
      }
    });

    room.active_participants = sortParticipants(merged);
    this.rooms = [...this.rooms];
  }
}
