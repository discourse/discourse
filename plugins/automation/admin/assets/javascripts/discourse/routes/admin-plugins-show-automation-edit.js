import { action } from "@ember/object";
import { hash } from "rsvp";
import { ajax } from "discourse/lib/ajax";
import DiscourseRoute from "discourse/routes/discourse";

export default class AutomationEdit extends DiscourseRoute {
  model(params) {
    return hash({
      scriptables: this.store
        .findAll("discourse-automation-scriptable")
        .then((result) => result.content),
      triggerables: ajax(
        `/admin/plugins/automation/triggerables.json?automation_id=${params.id}`
      ).then((result) => (result ? result.triggerables : [])),
      automation: this.store.find("discourse-automation-automation", params.id),
    });
  }

  setupController(controller, model) {
    const automation = model.automation;
    controller.setProperties({
      model,
      error: null,
      automationForm: {
        name: automation.name,
        enabled: automation.enabled,
        trigger: automation.trigger?.id,
        script: automation.script?.id,
        fields: automation.scriptFields().concat(automation.triggerFields()),
      },
    });
  }

  @action
  refreshRoute() {
    return this.refresh();
  }
}
