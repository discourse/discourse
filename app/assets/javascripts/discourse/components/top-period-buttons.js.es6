import computed from "ember-addons/ember-computed-decorators";

export default Ember.Component.extend({
  classNames: ["top-title-buttons"],

  @computed("period")
  periods(period) {
    return this.site.get("periods").filter(p => p !== period);
  },

  actions: {
    changePeriod(p) {
      this.action(p);
    }
  }
});
