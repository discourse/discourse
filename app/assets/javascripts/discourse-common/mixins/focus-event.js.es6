function gotFocus() {
  if (!Discourse.get("hasFocus")) {
    Discourse.setProperties({ hasFocus: true, notify: false });
  }
}

function lostFocus() {
  if (Discourse.get("hasFocus")) {
    Discourse.set("hasFocus", false);
  }
}

let onchange;

export default Ember.Mixin.create({
  ready() {
    this._super(...arguments);

    onchange = () => {
      document.visibilityState === "hidden" ? lostFocus() : gotFocus();
    };

    // Default to true
    Discourse.set("hasFocus", true);

    document.addEventListener("visibilitychange", onchange);
    document.addEventListener("resume", onchange);
    document.addEventListener("freeze", onchange);
  },

  reset() {
    this._super(...arguments);

    document.removeEventListener("visibilitychange", onchange);
    document.removeEventListener("resume", onchange);
    document.removeEventListener("freeze", onchange);

    onchange = undefined;
  }
});
