export default Ember.Component.extend({
  classNames: ["admin-report-counters"],

  attributeBindings: ["model.description:title"]
});
