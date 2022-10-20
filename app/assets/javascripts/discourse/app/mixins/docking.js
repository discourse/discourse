import Mixin from "@ember/object/mixin";
import discourseDebounce from "discourse-common/lib/debounce";
import { cancel } from "@ember/runloop";
import discourseLater from "discourse-common/lib/later";
import { bind } from "discourse-common/utils/decorators";

const INITIAL_DELAY_MS = 50;
const DEBOUNCE_MS = 5;

export default Mixin.create({
  _initialTimer: null,
  _queuedTimer: null,

  didInsertElement() {
    this._super(...arguments);

    window.addEventListener("scroll", this.queueDockCheck, { passive: true });
    document.addEventListener("touchmove", this.queueDockCheck, {
      passive: true,
    });

    // dockCheck might happen too early on full page refresh
    this._initialTimer = discourseLater(
      this,
      this.safeDockCheck,
      INITIAL_DELAY_MS
    );
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

  @bind
  queueDockCheck() {
    this._queuedTimer = discourseDebounce(
      this,
      this.safeDockCheck,
      DEBOUNCE_MS
    );
  },

  @bind
  safeDockCheck() {
    if (this.isDestroyed || this.isDestroying) {
      return;
    }
    this.dockCheck();
  },
});
