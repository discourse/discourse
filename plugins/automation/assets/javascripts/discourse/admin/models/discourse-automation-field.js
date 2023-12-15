import { tracked } from "@glimmer/tracking";
import { TrackedObject } from "@ember-compat/tracked-built-ins";

export default class DiscourseAutomationField {
  static create(template, target, json = {}) {
    const field = new DiscourseAutomationField();
    field.acceptsPlaceholders = template.accepts_placeholders;
    field.target = target;
    field.name = template.name;
    field.component = template.component;
    field.isDisabled = template.read_only;

    // backwards compatibility with forced scriptable fields
    if (field.isDisabled) {
      field.metadata.value =
        template.default_value || template.value || json?.metadata?.value;
    } else {
      field.metadata.value =
        template.value || json?.metadata?.value || template.default_value;
    }

    field.isRequired = template.is_required;
    field.extra = new TrackedObject(template.extra);
    return field;
  }

  @tracked acceptsPlaceholders = false;
  @tracked component;
  @tracked extra = new TrackedObject();
  @tracked isDisabled = false;
  @tracked isRequired = false;
  @tracked metadata = new TrackedObject();
  @tracked name;
  @tracked target;

  toJSON() {
    return {
      name: this.name,
      target: this.target,
      component: this.component,
      metadata: this.metadata,
    };
  }
}
