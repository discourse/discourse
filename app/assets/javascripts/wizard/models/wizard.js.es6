import Step from 'wizard/models/step';
import WizardField from 'wizard/models/wizard-field';
import { ajax } from 'wizard/lib/ajax';
import computed from 'ember-addons/ember-computed-decorators';

const Wizard = Ember.Object.extend({
  @computed('steps.length')
  totalSteps: length => length,

  getTitle() {
    const titleStep = this.get('steps').findBy('id', 'forum-title');
    if (!titleStep) { return; }
    return titleStep.get('fieldsById.title.value');
  },

  getLogoUrl() {
    const logoStep = this.get('steps').findBy('id', 'logos');
    if (!logoStep) { return; }
    return logoStep.get('fieldsById.logo_url.value');

  },

  // A bit clunky, but get the current colors from the appropriate step
  getCurrentColors() {
    const colorStep = this.get('steps').findBy('id', 'colors');
    if (!colorStep) { return; }

    const themeChoice = colorStep.get('fieldsById.base_scheme_id');
    if (!themeChoice) { return; }

    const themeId = themeChoice.get('value');
    if (!themeId) { return; }

    const choices = themeChoice.get('choices');
    if (!choices) { return; }

    const option = choices.findBy('id', themeId);
    if (!option) { return; }

    return option.data.colors;
  }

});

export function findWizard() {
  return ajax({ url: '/wizard.json' }).then(response => {
    const wizard = response.wizard;
    wizard.steps = wizard.steps.map(step => {
      const stepObj = Step.create(step);
      stepObj.fields = stepObj.fields.map(f => WizardField.create(f));
      return stepObj;
    });

    return Wizard.create(wizard);
  });
}
