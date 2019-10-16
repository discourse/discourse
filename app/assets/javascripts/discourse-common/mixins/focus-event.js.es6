import { getOwner } from "discourse-common/lib/get-owner";

export default Ember.Mixin.create({
  ready() {
    this._super(...arguments);

    this._onChangeHandler = Ember.run.bind(this, this._onChange);

    // Default to true
    Discourse.set("hasFocus", true);

    document.addEventListener("visibilitychange", this._onChangeHandler);
    document.addEventListener("resume", this._onChangeHandler);
    document.addEventListener("freeze", this._onChangeHandler);
  },

  reset() {
    this._super(...arguments);

    document.removeEventListener("visibilitychange", this._onChangeHandler);
    document.removeEventListener("resume", this._onChangeHandler);
    document.removeEventListener("freeze", this._onChangeHandler);

    this._onChangeHandler = null;
  },

  _onChange() {
    const container = getOwner(this);
    const appEvents = container.lookup("service:app-events");

    if (document.visibilityState === "hidden") {
      if (Discourse.hasFocus) {
        Discourse.set("hasFocus", false);
        appEvents.trigger("discourse:focus-changed", false);
      }
    } else {
      if (!Discourse.hasFocus) {
        Discourse.set("hasFocus", true);
        appEvents.trigger("discourse:focus-changed", true);
      }
    }
  }
});
