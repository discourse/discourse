import Mixin from "@ember/object/mixin";
import discourseDebounce from "discourse-common/lib/debounce";
import { cancel, later } from "@ember/runloop";

const helper = {
  offset() {
    const main = document.querySelector("#main");
    const offsetTop = main ? main.offsetTop : 0;
    return window.pageYOffset - offsetTop;
  },
};

export default Mixin.create({
  queueDockCheck: null,
  _initialTimer: null,
  _queuedTimer: null,

  init() {
    this._super(...arguments);
    this.queueDockCheck = () => {
      this._queuedTimer = discourseDebounce(this, this.safeDockCheck, 5);
    };
  },

  safeDockCheck() {
    if (this.isDestroyed || this.isDestroying) {
      return;
    }
    this.dockCheck(helper);
  },

  didInsertElement() {
    this._super(...arguments);

    window.addEventListener("scroll", this.queueDockCheck);
    document.addEventListener("touchmove", this.queueDockCheck);

    // dockCheck might happen too early on full page refresh
    this._initialTimer = later(this, this.safeDockCheck, 50);
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
