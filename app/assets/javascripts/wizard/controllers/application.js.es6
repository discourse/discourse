import Controller from "@ember/controller";
import discourseComputed from "discourse-common/utils/decorators";

export default Controller.extend({
  currentStepId: null,

  @discourseComputed("currentStepId")
  showCanvas(currentStepId) {
    return currentStepId === "finished";
  }
});
