import DiscourseRoute from "discourse/routes/discourse";
import { ajax } from "discourse/lib/ajax";
import { action } from "@ember/object";

export default DiscourseRoute.extend({
  controllerName: "admin-plugins-discourse-automation-edit",

  model(params) {
    return Ember.RSVP.hash({
      scriptables: this.store
        .findAll("discourse-automation-scriptable")
        .then(result => result.content),
      triggerables: ajax(
        `/admin/plugins/discourse-automation/triggerables.json?automation_id=${params.id}`
      ).then(result => (result ? result.triggerables : [])),
      automation: this.store.find("discourse-automation-automation", params.id)
    });
  },

  setupController(controller, model) {
    controller.setProperties({
      model,
      automationForm: {
        name: model.automation.name,
        enabled: model.automation.enabled,
        trigger: model.automation?.trigger?.id,
        script: model.automation?.script?.id,
        fields: model.automation?.fields || []
      }
    });
  },

  @action
  refreshRoute() {
    return this.refresh();
  }
});
