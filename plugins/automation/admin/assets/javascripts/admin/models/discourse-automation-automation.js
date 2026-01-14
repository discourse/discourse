import { tracked } from "@glimmer/tracking";
import RestModel from "discourse/models/rest";
import Field from "discourse/plugins/automation/admin/models/discourse-automation-field";

const ATTRIBUTES = ["name", "script", "fields", "trigger", "id"];

export default class Automation extends RestModel {
  @tracked enabled;

  updateProperties() {
    return {
      id: this.id,
      name: this.name,
      fields: this.fields,
      script: this.script.id,
      trigger: {
        id: this.trigger.id,
        name: this.trigger.name,
        metadata: this.trigger.metadata,
      },
    };
  }

  createProperties() {
    return this.getProperties(ATTRIBUTES);
  }

  get canBeEnabled() {
    for (const target of ["script", "trigger"]) {
      if (!this[target]) {
        return false;
      }

      for (const template of this[target].templates) {
        if (!template.is_required) {
          continue;
        }

        const field = this[target].fields.find(
          (f) => f.name === template.name && f.component === template.component
        );

        if (!field) {
          return false;
        }

        const val = field.metadata?.value;
        if (val === undefined || val === null || val.length === 0) {
          return false;
        }
      }
    }
    return true;
  }

  triggerFields() {
    return this.#fieldsForTarget("trigger");
  }

  scriptFields() {
    return this.#fieldsForTarget("script");
  }

  #fieldsForTarget(target) {
    return (this[target]?.templates || []).map((template) => {
      const jsonField = this[target].fields.find(
        (f) => f.name === template.name && f.component === template.component
      );
      return Field.create(
        template,
        {
          name: this[target].id,
          type: target,
        },
        jsonField
      );
    });
  }
}
