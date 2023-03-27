// temporary stuff to be moved in core with discourse-loading-slider

import Component from "@ember/component";
import { cancel, schedule } from "@ember/runloop";
import discourseLater from "discourse-common/lib/later";

const STORE_LOADING_TIMES = 5;
const DEFAULT_LOADING_TIME = 0.3;
const MIN_LOADING_TIME = 0.1;
const STILL_LOADING_DURATION = 2;

export default Component.extend({
  tagName: "",
  isLoading: false,
  key: null,

  init() {
    this._super(...arguments);

    this.loadingTimes = [DEFAULT_LOADING_TIME];
    this.set("averageTime", DEFAULT_LOADING_TIME);
    this.i = 0;
    this.scheduled = [];
  },

  resetState() {
    this.container?.classList?.remove("done", "loading", "still-loading");
  },

  cancelScheduled() {
    this.scheduled.forEach((s) => cancel(s));
    this.scheduled = [];
  },

  didReceiveAttrs() {
    this._super(...arguments);

    if (!this.key) {
      return;
    }

    this.cancelScheduled();
    this.resetState();

    if (this.isLoading) {
      this.start();
    } else {
      this.end();
    }
  },

  get container() {
    return document.getElementById(this.key);
  },

  start() {
    this.set("startedAt", Date.now());

    this.scheduled.push(discourseLater(this, "startLoading"));
    this.scheduled.push(
      discourseLater(this, "stillLoading", STILL_LOADING_DURATION * 1000)
    );
  },

  startLoading() {
    this.scheduled.push(
      schedule("afterRender", () => {
        this.container?.classList?.add("loading");
        document.documentElement.style.setProperty(
          "--loading-duration",
          `${this.averageTime.toFixed(2)}s`
        );
      })
    );
  },

  stillLoading() {
    this.scheduled.push(
      schedule("afterRender", () => {
        this.container?.classList?.add("still-loading");
      })
    );
  },

  end() {
    this.updateAverage((Date.now() - this.startedAt) / 1000);

    this.cancelScheduled();

    this.scheduled.push(
      schedule("afterRender", () => {
        this.container?.classList?.remove("loading", "still-loading");
        this.container?.classList?.add("done");
      })
    );
  },

  updateAverage(durationSeconds) {
    if (durationSeconds < MIN_LOADING_TIME) {
      durationSeconds = MIN_LOADING_TIME;
    }

    this.loadingTimes[this.i] = durationSeconds;

    this.i = (this.i + 1) % STORE_LOADING_TIMES;
    this.set(
      "averageTime",
      this.loadingTimes.reduce((p, c) => p + c, 0) / this.loadingTimes.length
    );
  },
});
