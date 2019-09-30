import { getOwner } from "discourse-common/lib/get-owner";

export default Ember.Mixin.create({
  ready() {
    this._super(...arguments);

    this.onChangeHandler = Ember.run.bind(this, "_onChange");

    document.addEventListener("visibilitychange", this.onChangeHandler);
  },

  reset() {
    this._super(...arguments);

    document.removeEventListener("visibilitychange", this.onChangeHandler);

    this.onchangeHandler = null;
  },

  _onChange() {
    const appEvents = getOwner(this).lookup("app-events:main");

    appEvents.trigger(
      "discourse:focus-changed",
      document.visibilityState === "visible"
    );
  }
});
