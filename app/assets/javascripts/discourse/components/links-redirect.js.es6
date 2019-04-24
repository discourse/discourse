import ClickTrack from "discourse/lib/click-track";

export default Ember.Component.extend({
  didInsertElement() {
    this._super(...arguments);

    this.$().on("click.discourse-redirect", "#revisions a", function(e) {
      return ClickTrack.trackClick(e);
    });
  },

  willDestroyElement() {
    this._super(...arguments);
    this.$().off("click.discourse-redirect", "#revisions a");
  }
});
