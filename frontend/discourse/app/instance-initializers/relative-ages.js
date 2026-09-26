import { lookup } from "discourse/lib/service";
import { isTesting } from "discourse/lib/environment";
import { updateRelativeAge } from "discourse/lib/formatter";
import A11yService from "discourse/services/a11y";

// Updates the relative ages of dates on the screen.
export default {
  initialize(owner) {
    if (isTesting()) {
      return;
    }

    const a11y = lookup(owner, A11yService);

    this._interval = setInterval(() => {
      updateRelativeAge(document.querySelectorAll(".relative-date"));
      a11y.autoUpdatingRelativeDateRef = new Date();
    }, 60 * 1000);
  },

  teardown() {
    if (this._interval) {
      clearInterval(this._interval);
      this._interval = null;
    }
  },
};
