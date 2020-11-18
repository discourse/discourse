import DiscourseRoute from "discourse/routes/discourse";
import EmberObject from "@ember/object";

export default DiscourseRoute.extend({
  controllerName: "admin-plugins-discourse-automation-edit",

  model(params) {
    return Ember.RSVP.hash({
      scripts: this.store.findAll("discourse-automation-script"),
      triggers: this.store.findAll("discourse-automation-trigger"),
      automation: this.store.find("discourse-automation-automation", params.id)
    });
  },

  setupController(controller, model) {
    controller.setProperties({
      model
    });
  }
});
