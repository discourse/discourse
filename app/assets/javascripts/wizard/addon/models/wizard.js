import EmberObject from "@ember/object";
import Evented from "@ember/object/evented";
import Step from "wizard/models/step";
import WizardField from "wizard/models/wizard-field";
import { ajax } from "discourse/lib/ajax";
import { readOnly } from "@ember/object/computed";

const Wizard = EmberObject.extend(Evented, {
  totalSteps: readOnly("steps.length"),

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

  get currentColors() {
    const colorStep = this.steps.findBy("id", "styling");
    if (!colorStep) {
      return this.current_color_scheme;
    }

    const themeChoice = colorStep.fieldsById.color_scheme;
    if (!themeChoice) {
      return;
    }

    return themeChoice.choices?.findBy("id", themeChoice.value)?.data.colors;
  },

  get font() {
    const fontChoice = this.steps.findBy("id", "styling")?.fieldsById
      ?.body_font;
    return fontChoice.choices?.findBy("id", fontChoice.value);
  },

  get headingFont() {
    const fontChoice = this.steps.findBy("id", "styling")?.fieldsById
      ?.heading_font;
    return fontChoice.choices?.findBy("id", fontChoice.value);
  },
});

export function findWizard() {
  return ajax({ url: "/wizard.json" }).then(({ wizard }) => {
    wizard.steps = wizard.steps.map((step) => {
      const stepObj = Step.create(step);
      stepObj.fields = stepObj.fields.map((f) => WizardField.create(f));
      return stepObj;
    });

    return Wizard.create(wizard);
  });
}
