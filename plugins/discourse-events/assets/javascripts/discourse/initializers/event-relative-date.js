import { cancel } from "@ember/runloop";
import { isTesting } from "discourse/lib/environment";
import discourseLater from "discourse/lib/later";
import eventRelativeDate from "../lib/event-relative-date";

function computeRelativeEventDates() {
  document
    .querySelectorAll(".event-relative-date.topic-list")
    .forEach((dateContainer) => eventRelativeDate(dateContainer));
}

export default {
  name: "event-future-date",

  initialize() {
    computeRelativeEventDates();

    if (!isTesting()) {
      this._tick();
    }
  },

  teardown() {
    if (this._interval) {
      cancel(this._interval);
      this._interval = null;
    }
  },

  _tick() {
    this._interval && cancel(this._interval);

    this._interval = discourseLater(() => {
      computeRelativeEventDates();
      this._tick();
    }, 60 * 1000);
  },
};
