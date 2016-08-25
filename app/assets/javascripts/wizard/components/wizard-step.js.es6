import { default as computed, observes } from 'ember-addons/ember-computed-decorators';

export default Ember.Component.extend({
  classNames: ['wizard-step'],
  saving: null,

  didInsertElement() {
    this._super();
    this.autoFocus();
  },

  @computed('step.displayIndex', 'wizard.totalSteps')
  showNextButton: (current, total) => current < total,

  @computed('step.index')
  showBackButton: index => index > 0,

  @observes('step.id')
  _stepChanged() {
    this.set('saving', false);
    this.autoFocus();
  },

  keyPress(key) {
    if (key.keyCode === 13) {
      this.send('nextStep');
    }
  },

  @computed('step.displayIndex', 'wizard.totalSteps')
  barStyle(displayIndex, totalSteps) {
    const ratio = parseFloat(displayIndex) / parseFloat(totalSteps) * 100;
    return Ember.String.htmlSafe(`width: ${ratio}%`);
  },

  autoFocus() {
    Ember.run.scheduleOnce('afterRender', () => {
      const $invalid = $('.wizard-field.invalid:eq(0) input');

      if ($invalid.length) {
        return $invalid.focus();
      }

      $('input:eq(0)').focus();
    });
  },

  saveStep() {
    const step = this.get('step');
    step.save()
      .then(() => this.sendAction('goNext'))
      .catch(response => {
        const errors = response.responseJSON.errors;
        if (errors && errors.length) {
          errors.forEach(err => {
            step.fieldError(err.field, err.description);
          });
        }
      });
  },

  actions: {
    backStep() {
      if (this.get('saving')) { return; }
      this.sendAction('goBack');
    },

    nextStep() {
      if (this.get('saving')) { return; }

      const step = this.get('step');
      step.checkFields();

      if (step.get('valid')) {
        this.set('saving', true);
        step.save()
          .then(() => this.sendAction('goNext'))
          .catch(() => null) // we can swallow because the form is already marked as invalid
          .finally(() => this.set('saving', false));
      } else {
        this.autoFocus();
      }
    }
  }
});
