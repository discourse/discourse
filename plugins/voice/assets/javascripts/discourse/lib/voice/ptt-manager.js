import { cancel } from "@ember/runloop";
import discourseLater from "discourse/lib/later";

const PTT_MUTE_DEBOUNCE_MS = 200;
const PTT_RESERVED_KEYS = new Set(["Escape", "Tab", "Enter"]);
const PTT_STORAGE_ENABLED = "voice_ptt_enabled";
const PTT_STORAGE_KEY = "voice_ptt_key";
const PTT_DEFAULT_KEY = "Space";

export { PTT_RESERVED_KEYS };

export default class PttManager {
  #enabled = false;
  #key = PTT_DEFAULT_KEY;
  #active = false;
  #listening = false;
  #muteDebounceTimer = null;
  #keyDownHandler = null;
  #keyUpHandler = null;
  #visibilityHandler = null;

  #onPress;
  #onReleaseImmediate;
  #onReleaseDebounced;
  #isConnected;

  constructor({
    onPress,
    onReleaseImmediate,
    onReleaseDebounced,
    isConnected,
  }) {
    this.#onPress = onPress;
    this.#onReleaseImmediate = onReleaseImmediate;
    this.#onReleaseDebounced = onReleaseDebounced;
    this.#isConnected = isConnected;

    this.#enabled = localStorage.getItem(PTT_STORAGE_ENABLED) === "true";
    this.#key = localStorage.getItem(PTT_STORAGE_KEY) || PTT_DEFAULT_KEY;
  }

  get enabled() {
    return this.#enabled;
  }

  get key() {
    return this.#key;
  }

  get active() {
    return this.#active;
  }

  enable() {
    this.#enabled = true;
    this.#active = false;
    localStorage.setItem(PTT_STORAGE_ENABLED, "true");
  }

  disable() {
    if (this.#active) {
      this.#doRelease();
    }
    this.#enabled = false;
    this.#active = false;
    localStorage.setItem(PTT_STORAGE_ENABLED, "false");
    this.stopListening();
  }

  setKey(keyCode) {
    if (PTT_RESERVED_KEYS.has(keyCode)) {
      return false;
    }
    this.#key = keyCode;
    localStorage.setItem(PTT_STORAGE_KEY, keyCode);
    return true;
  }

  startListening() {
    if (this.#listening) {
      return;
    }
    this.#listening = true;

    this.#keyDownHandler = (event) => this.#onKeyDown(event);
    this.#keyUpHandler = (event) => this.#onKeyUp(event);
    this.#visibilityHandler = () => this.#onVisibilityChange();

    document.addEventListener("keydown", this.#keyDownHandler);
    document.addEventListener("keyup", this.#keyUpHandler);
    document.addEventListener("visibilitychange", this.#visibilityHandler);
  }

  stopListening() {
    if (!this.#listening) {
      return;
    }
    this.#listening = false;

    if (this.#keyDownHandler) {
      document.removeEventListener("keydown", this.#keyDownHandler);
      this.#keyDownHandler = null;
    }
    if (this.#keyUpHandler) {
      document.removeEventListener("keyup", this.#keyUpHandler);
      this.#keyUpHandler = null;
    }
    if (this.#visibilityHandler) {
      document.removeEventListener("visibilitychange", this.#visibilityHandler);
      this.#visibilityHandler = null;
    }
    this.#cancelDebounce();
  }

  resetActive() {
    this.#active = false;
  }

  destroy() {
    this.stopListening();
  }

  // --- Private ---

  #onKeyDown(event) {
    if (!this.#enabled || !this.#isConnected()) {
      return;
    }

    if (event.code !== this.#key) {
      return;
    }

    if (this.#isTypingInInput()) {
      return;
    }

    event.preventDefault();

    if (event.repeat || this.#active) {
      return;
    }

    this.#cancelDebounce();
    this.#active = true;
    this.#onPress();
  }

  #onKeyUp(event) {
    if (!this.#enabled || event.code !== this.#key) {
      return;
    }

    if (!this.#isTypingInInput()) {
      event.preventDefault();
    }

    if (!this.#active) {
      return;
    }

    this.#doRelease();
  }

  #doRelease() {
    this.#active = false;
    this.#onReleaseImmediate();
    this.#cancelDebounce();

    this.#muteDebounceTimer = discourseLater(
      this,
      () => {
        this.#muteDebounceTimer = null;
        this.#onReleaseDebounced();
      },
      PTT_MUTE_DEBOUNCE_MS
    );
  }

  #onVisibilityChange() {
    if (document.hidden && this.#active) {
      this.#doRelease();
    }
  }

  #cancelDebounce() {
    if (this.#muteDebounceTimer) {
      cancel(this.#muteDebounceTimer);
      this.#muteDebounceTimer = null;
    }
  }

  #isTypingInInput() {
    const el = document.activeElement;
    if (!el) {
      return false;
    }
    const tag = el.tagName;
    return (
      tag === "INPUT" ||
      tag === "TEXTAREA" ||
      tag === "SELECT" ||
      el.isContentEditable
    );
  }
}
