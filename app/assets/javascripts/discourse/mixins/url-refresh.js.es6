// A Mixin that a view can use to listen for 'url:refresh' when
// it is on screen, and will send an action to refresh its data.
//
// This is useful if you want to get around Ember's default
// behavior of not refreshing when navigating to the same place.
export default {
  didInsertElement() {
    this._super(...arguments);

    this.appEvents.on("url:refresh", this, "refresh");
  },

  willDestroyElement() {
    this._super(...arguments);

    this.appEvents.off("url:refresh", this, "refresh");
  }
};
