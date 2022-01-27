import Controller from "@ember/controller";
import { dasherize } from "@ember/string";
import discourseComputed from "discourse-common/utils/decorators";

export default Controller.extend({
  currentStepId: null,

  @discourseComputed("currentStepId")
  showCanvas(currentStepId) {
    return currentStepId === "finished";
  },

  @discourseComputed("model")
  fontClasses(model) {
    const fontsStep = model.steps.findBy("id", "styling");
    if (!fontsStep) {
      return [];
    }

    const fontField = fontsStep.get("fieldsById.body_font");
    return fontField.choices.map(
      (choice) => `body-font-${dasherize(choice.id)}`
    );
  },
});
