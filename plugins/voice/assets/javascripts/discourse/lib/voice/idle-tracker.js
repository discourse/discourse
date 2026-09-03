// Site settings express the idle ladder in minutes; a later stage set at or
// below an earlier one disables the earlier stage rather than firing out of
// order.
export function idleThresholds(siteSettings) {
  let idleMs = siteSettings.voice_idle_threshold_minutes * 60 * 1000;
  let afkMs = siteSettings.voice_afk_auto_mute_threshold_minutes * 60 * 1000;
  let disconnectMs =
    siteSettings.voice_afk_disconnect_threshold_minutes * 60 * 1000;

  if (afkMs > 0 && idleMs > 0 && idleMs >= afkMs) {
    idleMs = 0;
  }
  if (disconnectMs > 0 && afkMs > 0 && afkMs >= disconnectMs) {
    afkMs = 0;
  }
  if (disconnectMs > 0 && idleMs > 0 && idleMs >= disconnectMs) {
    idleMs = 0;
  }

  return { idleMs, afkMs, disconnectMs };
}

export default class IdleTracker {
  #lastActivityAt = 0;
  #idleCheckTimerId = null;
  #activityThrottled = false;
  #wasAutoMuted = false;
  #lastBroadcastedIdleState = null;
  #boundActivityHandler = null;
  #voiceActivityThrottled = false;

  #onIdleStateChange;
  #onAutoMute;
  #onDisconnect;
  #getThresholds;

  constructor({ onIdleStateChange, onAutoMute, onDisconnect, getThresholds }) {
    this.#onIdleStateChange = onIdleStateChange;
    this.#onAutoMute = onAutoMute;
    this.#onDisconnect = onDisconnect;
    this.#getThresholds = getThresholds;
  }

  get wasAutoMuted() {
    return this.#wasAutoMuted;
  }

  set wasAutoMuted(value) {
    this.#wasAutoMuted = value;
  }

  get lastBroadcastedIdleState() {
    return this.#lastBroadcastedIdleState;
  }

  set lastBroadcastedIdleState(value) {
    this.#lastBroadcastedIdleState = value;
  }

  start() {
    if (this.#idleCheckTimerId) {
      return;
    }

    this.#lastActivityAt = Date.now();
    this.#wasAutoMuted = false;
    this.#lastBroadcastedIdleState = null;

    this.#boundActivityHandler = () => this.resetActivity();
    const events = [
      "mousemove",
      "mousedown",
      "keydown",
      "scroll",
      "touchstart",
    ];
    events.forEach((event) => {
      document.addEventListener(event, this.#boundActivityHandler, {
        passive: true,
      });
    });

    this.#idleCheckTimerId = setInterval(() => this.#check(), 30000);
  }

  stop() {
    if (this.#idleCheckTimerId) {
      clearInterval(this.#idleCheckTimerId);
      this.#idleCheckTimerId = null;
    }

    if (this.#boundActivityHandler) {
      const events = [
        "mousemove",
        "mousedown",
        "keydown",
        "scroll",
        "touchstart",
      ];
      events.forEach((event) => {
        document.removeEventListener(event, this.#boundActivityHandler);
      });
      this.#boundActivityHandler = null;
    }

    this.#wasAutoMuted = false;
    this.#activityThrottled = false;
    this.#voiceActivityThrottled = false;
    this.#lastBroadcastedIdleState = null;
  }

  resetActivity() {
    if (this.#activityThrottled) {
      this.#lastActivityAt = Date.now();
      return;
    }

    this.#lastActivityAt = Date.now();
    this.#activityThrottled = true;
    setTimeout(() => {
      this.#activityThrottled = false;
    }, 10000);

    this.#onIdleStateChange("active", this.#wasAutoMuted);
  }

  onVoiceActivity() {
    if (this.#voiceActivityThrottled) {
      return;
    }

    this.#voiceActivityThrottled = true;
    setTimeout(() => {
      this.#voiceActivityThrottled = false;
    }, 10000);

    this.resetActivity();
  }

  #check() {
    const { idleMs, afkMs, disconnectMs } = this.#getThresholds();
    const elapsed = Date.now() - this.#lastActivityAt;

    if (disconnectMs > 0 && elapsed >= disconnectMs) {
      this.#onDisconnect();
      return;
    }

    if (afkMs > 0 && elapsed >= afkMs) {
      this.#wasAutoMuted = true;
      this.#lastBroadcastedIdleState = null;
      this.#onAutoMute();
      return;
    }

    if (idleMs > 0 && elapsed >= idleMs) {
      this.#lastBroadcastedIdleState = null;
      this.#onIdleStateChange("idle", false);
      return;
    }

    this.#onIdleStateChange("active", false);
  }
}
