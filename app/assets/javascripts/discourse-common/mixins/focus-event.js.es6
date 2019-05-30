function gotFocus() {
  if (!Discourse.hasFocus) {
    Discourse.setProperties({ hasFocus: true, notify: false });
  }
}

function lostFocus() {
  if (Discourse.hasFocus) {
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
  },

  reset() {
    this._super(...arguments);

    document.removeEventListener("visibilitychange", onchange);

    onchange = undefined;
  }
});
