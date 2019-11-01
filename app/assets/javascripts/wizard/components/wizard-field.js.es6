import Component from "@ember/component";
import computed from "ember-addons/ember-computed-decorators";

export default Component.extend({
  classNameBindings: [":wizard-field", "typeClass", "field.invalid"],

  @computed("field.type")
  typeClass: type => `${Ember.String.dasherize(type)}-field`,

  @computed("field.id")
  fieldClass: id => `field-${Ember.String.dasherize(id)} wizard-focusable`,

  @computed("field.type", "field.id")
  inputComponentName(type, id) {
    return type === "component"
      ? Ember.String.dasherize(id)
      : `wizard-field-${type}`;
  }
});
