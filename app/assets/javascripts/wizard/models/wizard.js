import EmberObject from "@ember/object";
import Evented from "@ember/object/evented";
import Step from "wizard/models/step";
import WizardField from "wizard/models/wizard-field";
import { ajax } from "wizard/lib/ajax";
import discourseComputed from "discourse-common/utils/decorators";

const Wizard = EmberObject.extend(Evented, {
  @discourseComputed("steps.length")
  totalSteps: (length) => length,

  getTitle() {
    const titleStep = this.steps.findBy("id", "forum-title");
    if (!titleStep) {
      return;
    }
    return titleStep.get("fieldsById.title.value");
  },

  getLogoUrl() {
    const logoStep = this.steps.findBy("id", "logos");
    if (!logoStep) {
      return;
    }
    return logoStep.get("fieldsById.logo.value");
  },

  // A bit clunky, but get the current colors from the appropriate step
  getCurrentColors(schemeId) {
    const colorStep = this.steps.findBy("id", "styling");
    if (!colorStep) {
      return this.current_color_scheme;
    }

    const themeChoice = colorStep.get("fieldsById.color_scheme");
    if (!themeChoice) {
      return;
    }

    const themeId = schemeId ? schemeId : themeChoice.get("value");
    if (!themeId) {
      return;
    }

    const choices = themeChoice.get("choices");
    if (!choices) {
      return;
    }

    const option = choices.findBy("id", themeId);
    if (!option) {
      return;
    }

    return option.data.colors;
  },

  getCurrentFont(fontId, type = "body_font") {
    const fontsStep = this.steps.findBy("id", "styling");
    if (!fontsStep) {
      return;
    }

    const fontChoice = fontsStep.get(`fieldsById.${type}`);
    if (!fontChoice) {
      return;
    }

    const choiceId = fontId ? fontId : fontChoice.get("value");
    if (!choiceId) {
      return;
    }

    const choices = fontChoice.get("choices");
    if (!choices) {
      return;
    }

    const option = choices.findBy("id", choiceId);
    if (!option) {
      return;
    }

    return option.label;
  },
});

export function findWizard() {
  return ajax({ url: "/wizard.json" }).then((response) => {
    const wizard = response.wizard;
    wizard.steps = wizard.steps.map((step) => {
      const stepObj = Step.create(step);
      stepObj.fields = stepObj.fields.map((f) => WizardField.create(f));
      return stepObj;
    });

    return Wizard.create(wizard);
  });
}
