import DiscourseRoute from "discourse/routes/discourse";
import { ajax } from "discourse/lib/ajax";

export default DiscourseRoute.extend({
  controllerName: "admin-plugins-discourse-automation-edit",

  model(params) {
    return Ember.RSVP.hash({
      scriptables: this.store.findAll("discourse-automation-scriptable"),
      triggerables: ajax(
        `/admin/plugins/discourse-automation/triggerables.json?automation_id=${params.id}`
      ).then((result) => (result ? result.triggerables : [])),
      automation: this.store.find("discourse-automation-automation", params.id),
    });
  },

  setupController(controller, model) {
    controller.setProperties({
      model,
    });
  },
});
