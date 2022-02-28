import DiscourseRoute from "discourse/routes/discourse";
import { isPresent } from "@ember/utils";
import EmberObject, { action } from "@ember/object";
import { ajax } from "discourse/lib/ajax";
import { hash } from "rsvp";

export default class AutomationEdit extends DiscourseRoute {
  controllerName = "admin-plugins-discourse-automation-edit";

  model(params) {
    return hash({
      scriptables: this.store
        .findAll("discourse-automation-scriptable")
        .then((result) => result.content),
      triggerables: ajax(
        `/admin/plugins/discourse-automation/triggerables.json?automation_id=${params.id}`
      ).then((result) => (result ? result.triggerables : [])),
      automation: this.store.find("discourse-automation-automation", params.id),
    });
  }

  _fieldsForTarget(automation, target) {
    return (automation[target].templates || []).map((template) => {
      const field = automation[target].fields.find(
        (f) => f.name === template.name && f.component === template.component
      );

      return EmberObject.create({
        acceptsPlaceholders: template.accepts_placeholders,
        target,
        name: template.name,
        component: template.component,
        metadata: {
          value:
            template.default_value || template.value || field?.metadata?.value,
        },
        isDisabled: isPresent(template.default_value),
        isRequired: template.is_required,
        extra: template.extra,
      });
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
        fields: this._fieldsForTarget(automation, "script").concat(
          this._fieldsForTarget(automation, "trigger")
        ),
      },
    });
  }

  @action
  refreshRoute() {
    return this.refresh();
  }
}
