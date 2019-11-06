import Component from "@ember/component";
import computed from "ember-addons/ember-computed-decorators";
const { isEmpty } = Ember;

export default Component.extend({
  layoutName: "select-kit/templates/components/select-kit/select-kit-filter",
  classNames: ["select-kit-filter"],
  classNameBindings: ["isFocused", "isHidden"],
  isHidden: Ember.computed.not("shouldDisplayFilter"),

  @computed("placeholder")
  computedPlaceholder(placeholder) {
    return isEmpty(placeholder) ? "" : I18n.t(placeholder);
  }
});
