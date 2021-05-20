import Mixin from "@ember/object/mixin";
import discourseDebounce from "discourse-common/lib/debounce";
import { cancel, later } from "@ember/runloop";

const helper = {
  offset() {
    const mainOffset = $("#main").offset();
    const offsetTop = mainOffset ? mainOffset.top : 0;
    return (window.pageYOffset || $("html").scrollTop()) - offsetTop;
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

    $(window).bind("scroll.discourse-dock", this.queueDockCheck);
    $(document).bind("touchmove.discourse-dock", this.queueDockCheck);

    // dockCheck might happen too early on full page refresh
    this._initialTimer = later(this, this.safeDockCheck, 50);
  },

  willDestroyElement() {
    this._super(...arguments);

    if (this._queuedTimer) {
      cancel(this._queuedTimer);
    }

    cancel(this._initialTimer);
    $(window).unbind("scroll.discourse-dock", this.queueDockCheck);
    $(document).unbind("touchmove.discourse-dock", this.queueDockCheck);
  },
});
