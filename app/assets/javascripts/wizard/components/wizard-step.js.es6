import { default as computed, observes } from 'ember-addons/ember-computed-decorators';

jQuery.fn.wiggle = function (times, duration) {
  if (times > 0) {
    this.animate({
      marginLeft: times-- % 2 === 0 ? -15 : 15
    }, duration, 0, () => this.wiggle(times, duration));
  } else {
    this.animate({ marginLeft: 0 }, duration, 0);
  }
  return this;
};

export default Ember.Component.extend({
  classNames: ['wizard-step'],
  saving: null,

  didInsertElement() {
    this._super();
    this.autoFocus();
  },

  @computed('step.index')
  showQuitButton: index => index === 0,

  @computed('step.displayIndex', 'wizard.totalSteps')
  showNextButton: (current, total) => current < total,

  @computed('step.displayIndex', 'wizard.totalSteps')
  showDoneButton: (current, total) => current === total,

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

  animateInvalidFields() {
    Ember.run.scheduleOnce('afterRender', () => $('.invalid input[type=text]').wiggle(2, 100));
  },

  actions: {
    quit() {
      document.location = "/";
    },

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
          .then(response => this.sendAction('goNext', response))
          .catch(() => this.animateInvalidFields()) 
          .finally(() => this.set('saving', false));
      } else {
        this.animateInvalidFields();
        this.autoFocus();
      }
    }
  }
});
