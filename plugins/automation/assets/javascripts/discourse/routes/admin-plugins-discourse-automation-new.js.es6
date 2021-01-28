import DiscourseRoute from "discourse/routes/discourse";

export default DiscourseRoute.extend({
  controllerName: "admin-plugins-discourse-automation-new",

  model() {
    return Ember.RSVP.hash({
      scriptables: this.store.findAll("discourse-automation-scriptable"),
      automation: this.store.createRecord("discourse-automation-automation"),
    });
  },
});
