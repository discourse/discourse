import Service, { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { bind } from "discourse/lib/decorators";
import { isPrimaryTab } from "discourse/lib/utilities";
import VoiceIncomingCallModal from "../../components/modal/voice-incoming-call";
import { claimCallAlert } from "../../lib/voice/call-alert-dedup";
import { RING_SECONDS } from "../../lib/voice/call-constants";
import { setPendingInviteRef } from "../../lib/voice/invite-ref";
import { startRingtone, stopCallSounds } from "../../lib/voice/sound-effects";

// Direct calls: starts them (user-card button) and answers them (the ring
// event published when someone invites this user into an ephemeral room).
export default class VoiceCallsService extends Service {
  @service currentUser;
  @service messageBus;
  @service modal;
  @service router;
  @service("voice-rooms") voiceRooms;
  @service("voice-webrtc") voiceWebrtc;

  #subscribed = false;
  #ringtoneRetry = null;

  willDestroy() {
    super.willDestroy(...arguments);
    if (this.#subscribed) {
      this.messageBus.unsubscribe(this.#ringChannel, this.onRing);
    }
    this.#cancelRingtoneRetry();
    stopCallSounds();
  }

  listen() {
    if (this.#subscribed || !this.currentUser) {
      return;
    }
    this.#subscribed = true;
    this.messageBus.subscribe(this.#ringChannel, this.onRing);
  }

  // Creates the ephemeral call room, rings the callee, and lands the caller
  // on the room page with an auto-join. The webrtc service loops the waiting
  // tone once the caller is connected and alone, and silences it when the
  // callee's peer arrives.
  async callUser(username) {
    const response = await ajax("/voice/calls", {
      type: "POST",
      data: { username },
    });

    const room = response.room;
    this.voiceRooms.upsertRoom?.(room);
    this.router.transitionTo("voice-room", room.slug, {
      queryParams: { join: "true" },
    });

    return room;
  }

  @bind
  async onRing(data) {
    if (!data?.room_id) {
      return;
    }

    // A tab waking up replays the channel backlog — only rings still within
    // their window are real.
    const ringMs = (data.ring_seconds ?? RING_SECONDS) * 1000;
    const remainingMs = data.sent_at * 1000 + ringMs - Date.now();
    if (remainingMs <= 0) {
      return;
    }

    // Already in that call (answered from the push notification, or rung for
    // a room this user is sitting in).
    if (this.voiceWebrtc.activeRoomId === data.room_id) {
      return;
    }

    // Same dedup as notification sounds: only the primary tab handles the
    // ring, and the claim keeps a late backlog replay from ringing twice.
    if (!(await isPrimaryTab())) {
      return;
    }
    if (
      !claimCallAlert(`${data.room_id}-${data.caller_username}-${data.sent_at}`)
    ) {
      return;
    }

    // Best effort: without a prior user gesture in this tab the browser
    // keeps the AudioContext suspended. The answer modal still shows, and
    // the first gesture while it's up starts the ringtone late.
    startRingtone(this.currentUser.chat_sound).then((played) => {
      if (!played && !this.isDestroying) {
        this.#retryRingtoneOnGesture();
      }
    });
    this.modal
      .show(VoiceIncomingCallModal, {
        model: { ring: data, remainingMs, calls: this },
      })
      .finally(() => {
        this.#cancelRingtoneRetry();
        stopCallSounds();
      });
  }

  answer(ring) {
    stopCallSounds();
    // Joining through the invite ref credits the caller, the same as joining
    // from the notification link.
    setPendingInviteRef(ring.room_slug, ring.caller_username);
    this.router.transitionTo("voice-room", ring.room_slug, {
      queryParams: { join: "true" },
    });
  }

  get #ringChannel() {
    return `/voice/call-ring/${this.currentUser.id}`;
  }

  // If the retried start lands on a gesture that also ends the ring (e.g.
  // clicking Answer), the modal's close bumps the sound generation and the
  // late start is discarded — it can't outlive the ring.
  #retryRingtoneOnGesture() {
    this.#cancelRingtoneRetry();

    const retry = () => {
      this.#cancelRingtoneRetry();
      startRingtone(this.currentUser.chat_sound);
    };
    this.#ringtoneRetry = retry;
    document.addEventListener("pointerdown", retry, { once: true });
    document.addEventListener("keydown", retry, { once: true });
  }

  #cancelRingtoneRetry() {
    if (this.#ringtoneRetry) {
      document.removeEventListener("pointerdown", this.#ringtoneRetry);
      document.removeEventListener("keydown", this.#ringtoneRetry);
      this.#ringtoneRetry = null;
    }
  }
}
