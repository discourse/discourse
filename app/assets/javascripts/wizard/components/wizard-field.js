import Component from "@ember/component";
import { dasherize } from "@ember/string";
import discourseComputed from "discourse-common/utils/decorators";

export default Component.extend({
  classNameBindings: [":wizard-field", "typeClasses", "field.invalid"],

  @discourseComputed("field.type", "field.id")
  typeClasses: (type, id) =>
    `${dasherize(type)}-field ${dasherize(type)}-${dasherize(id)}`,

  @discourseComputed("field.id")
  fieldClass: (id) => `field-${dasherize(id)} wizard-focusable`,

  @discourseComputed("field.type", "field.id")
  inputComponentName(type, id) {
    return type === "component" ? dasherize(id) : `wizard-field-${type}`;
  },
});
