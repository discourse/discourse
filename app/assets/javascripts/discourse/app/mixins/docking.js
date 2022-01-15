import Mixin from "@ember/object/mixin";
import discourseDebounce from "discourse-common/lib/debounce";
import { cancel, later } from "@ember/runloop";
import { isTesting } from "discourse-common/config/environment";

const INITIAL_DELAY_MS = isTesting() ? 0 : 50;
const DEBOUNCE_MS = isTesting() ? 0 : 5;

export default Mixin.create({
  queueDockCheck: null,
  _initialTimer: null,
  _queuedTimer: null,

  init() {
    this._super(...arguments);
    this.queueDockCheck = () => {
      this._queuedTimer = discourseDebounce(
        this,
        this.safeDockCheck,
        DEBOUNCE_MS
      );
    };
  },

  safeDockCheck() {
    if (this.isDestroyed || this.isDestroying) {
      return;
    }
    this.dockCheck();
  },

  didInsertElement() {
    this._super(...arguments);

    window.addEventListener("scroll", this.queueDockCheck, { passive: true });
    document.addEventListener("touchmove", this.queueDockCheck, {
      passive: true,
    });

    // dockCheck might happen too early on full page refresh
    this._initialTimer = later(this, this.safeDockCheck, INITIAL_DELAY_MS);
  },

  willDestroyElement() {
    this._super(...arguments);

    if (this._queuedTimer) {
      cancel(this._queuedTimer);
    }

    cancel(this._initialTimer);
    window.removeEventListener("scroll", this.queueDockCheck);
    document.removeEventListener("touchmove", this.queueDockCheck);
  },
});
