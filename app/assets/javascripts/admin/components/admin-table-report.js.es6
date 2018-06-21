import computed from "ember-addons/ember-computed-decorators";

export default Ember.Component.extend({
  @computed("model.sortedData")
  totalForPeriod(data) {
    const values = data.map(d => d.y);
    return values.reduce((sum, v) => sum + v);
  }
});
