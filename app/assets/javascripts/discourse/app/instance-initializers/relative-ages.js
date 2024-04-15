import { updateRelativeAge } from "discourse/lib/formatter";

// Updates the relative ages of dates on the screen.
export default {
  initialize() {
    this._interval = setInterval(function () {
      updateRelativeAge(document.querySelectorAll(".relative-date"));
    }, 60 * 1000);
  },

  teardown() {
    if (this._interval) {
      clearInterval(this._interval);
      this._interval = null;
    }
  },
};
