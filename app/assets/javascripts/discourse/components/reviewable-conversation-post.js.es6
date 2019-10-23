import Component from "@ember/component";
export default Component.extend({
  showUsername: Ember.computed.gte("index", 1)
});
