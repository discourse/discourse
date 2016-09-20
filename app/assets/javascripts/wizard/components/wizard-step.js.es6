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

const alreadyWarned = {};

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

  @computed('step.banner')
  bannerImage(src) {
    if (!src) { return; }
    return `/images/wizard/${src}`;
  },

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

  advance() {
    this.set('saving', true);
    this.get('step').save()
      .then(response => this.sendAction('goNext', response))
      .catch(() => this.animateInvalidFields())
      .finally(() => this.set('saving', false));
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
      const result = step.validate();

      if (result.warnings.length) {
        const unwarned = result.warnings.filter(w => !alreadyWarned[w]);
        if (unwarned.length) {
          unwarned.forEach(w => alreadyWarned[w] = true);
          return window.swal({
            customClass: 'wizard-warning',
            title: "",
            text: unwarned.map(w => I18n.t(`wizard.${w}`)).join("\n"),
            type: 'warning',
            showCancelButton: true,
            confirmButtonColor: "#6699ff"
          }, confirmed => {
            if (confirmed) {
              this.advance();
            }
          });
        }
      }

      if (step.get('valid')) {
        this.advance();
      } else {
        this.animateInvalidFields();
        this.autoFocus();
      }
    }
  }
});
