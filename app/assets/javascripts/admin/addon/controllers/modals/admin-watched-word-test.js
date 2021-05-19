import Controller from "@ember/controller";
import ModalFunctionality from "discourse/mixins/modal-functionality";
import discourseComputed from "discourse-common/utils/decorators";

export default Controller.extend(ModalFunctionality, {
  @discourseComputed("value", "model.compiledRegularExpression")
  matches(value, regexpString) {
    if (!value || !regexpString) {
      return;
    }
    let censorRegexp = new RegExp(regexpString, "ig");
    return value.match(censorRegexp);
  },
});
