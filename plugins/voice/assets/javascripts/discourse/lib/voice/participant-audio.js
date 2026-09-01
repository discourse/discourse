import { applyOutputDevice } from "./media-devices";

// Per-participant playback state: which media elements a remote user's audio
// plays through, plus the local volume and mute the listener chose for them.
// Deafen state stays with the caller and is consulted through a callback so
// it applies uniformly whenever settings are (re)applied.
export default class ParticipantAudio {
  #elements = new Map();
  #volumes = new Map();
  #muted = new Map();

  #isDeafened;

  constructor({ isDeafened }) {
    this.#isDeafened = isDeafened;
  }

  trackElement(roomId, userId, element, role = "voice") {
    const key = this.#key(roomId, userId);
    const elements = this.#elements.get(key) || {};
    elements[role] = element;
    this.#elements.set(key, elements);
  }

  untrackElement(roomId, userId) {
    this.#elements.delete(this.#key(roomId, userId));
  }

  setVolume(roomId, userId, volume) {
    const clamped = Math.max(0, Math.min(1, volume));
    this.#volumes.set(this.#key(roomId, userId), clamped);
    this.apply(roomId, userId);
  }

  volumeFor(roomId, userId) {
    return this.#volumes.get(this.#key(roomId, userId)) ?? 1;
  }

  toggleMuted(roomId, userId) {
    const key = this.#key(roomId, userId);
    const newMutedState = !(this.#muted.get(key) ?? false);
    this.#muted.set(key, newMutedState);
    this.apply(roomId, userId);
    return newMutedState;
  }

  isMuted(roomId, userId) {
    return this.#muted.get(this.#key(roomId, userId)) ?? false;
  }

  apply(roomId, userId) {
    const key = this.#key(roomId, userId);
    const elements = this.#elements.get(key);
    if (!elements) {
      return;
    }

    this.#applyTo(key, elements);
  }

  applyAll() {
    for (const [key, elements] of this.#elements) {
      this.#applyTo(key, elements);
    }
  }

  setOutputDevice(deviceId) {
    for (const [, elements] of this.#elements) {
      for (const element of Object.values(elements)) {
        applyOutputDevice(element, deviceId);
      }
    }
  }

  #key(roomId, userId) {
    return `${roomId}:${userId}`;
  }

  #applyTo(key, elements) {
    const muted = this.#isDeafened() || (this.#muted.get(key) ?? false);
    const volume = this.#volumes.get(key) ?? 1;

    for (const element of Object.values(elements)) {
      element.muted = muted;
      if (!muted) {
        element.volume = volume;
      }
    }
  }
}
