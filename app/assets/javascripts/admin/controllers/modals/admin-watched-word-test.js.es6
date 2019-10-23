import Controller from "@ember/controller";
import { default as computed } from "ember-addons/ember-computed-decorators";
import ModalFunctionality from "discourse/mixins/modal-functionality";

export default Controller.extend(ModalFunctionality, {
  @computed("value", "model.compiledRegularExpression")
  matches(value, regexpString) {
    if (!value || !regexpString) return;
    let censorRegexp = new RegExp(regexpString, "ig");
    return value.match(censorRegexp);
  }
});
