import Controller from "@ember/controller";
import discourseComputed from "discourse-common/utils/decorators";
import ModalFunctionality from "discourse/mixins/modal-functionality";

export default Controller.extend(ModalFunctionality, {
  @discourseComputed("value", "model.compiledRegularExpression")
  matches(value, regexpString) {
    if (!value || !regexpString) return;
    let censorRegexp = new RegExp(regexpString, "ig");
    return value.match(censorRegexp);
  }
});
