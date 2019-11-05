import Component from "@ember/component";
import computed from "ember-addons/ember-computed-decorators";
import { dasherize } from "@ember/string";

export default Component.extend({
  classNameBindings: [":wizard-field", "typeClass", "field.invalid"],

  @computed("field.type")
  typeClass: type => `${dasherize(type)}-field`,

  @computed("field.id")
  fieldClass: id => `field-${dasherize(id)} wizard-focusable`,

  @computed("field.type", "field.id")
  inputComponentName(type, id) {
    return type === "component" ? dasherize(id) : `wizard-field-${type}`;
  }
});
