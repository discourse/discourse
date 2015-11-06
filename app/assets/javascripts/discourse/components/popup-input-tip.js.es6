import StringBuffer from 'discourse/mixins/string-buffer';
import { iconHTML } from 'discourse/helpers/fa-icon';
import { default as computed, observes } from 'ember-addons/ember-computed-decorators';

export default Ember.Component.extend(StringBuffer, {
  classNameBindings: [':popup-tip', 'good', 'bad', 'lastShownAt::hide'],
  animateAttribute: null,
  bouncePixels: 6,
  bounceDelay: 100,
  rerenderTriggers: ['validation.reason'],

  click() {
    this.set('shownAt', null);
    this.set('validation.lastShownAt', null);
  },

  bad: Ember.computed.alias("validation.failed"),
  good: Ember.computed.not("bad"),

  @computed('shownAt', 'validation.lastShownAt')
  lastShownAt(shownAt, lastShownAt) {
    return shownAt || lastShownAt;
  },

  @observes('lastShownAt')
  bounce() {
    if (this.get("lastShownAt")) {
      var $elem = this.$();
      if (!this.animateAttribute) {
        this.animateAttribute = $elem.css('left') === 'auto' ? 'right' : 'left';
      }
      if (this.animateAttribute === 'left') {
        this.bounceLeft($elem);
      } else {
        this.bounceRight($elem);
      }
    }
  },

  renderString(buffer) {
    const reason = this.get('validation.reason');
    if (!reason) { return; }

    buffer.push(`<span class='close'>${iconHTML('times-circle')}</span>${reason}`);
  },

  bounceLeft($elem) {
    for (var i = 0; i < 5; i++) {
      $elem.animate({ left: '+=' + this.bouncePixels }, this.bounceDelay).animate({ left: '-=' + this.bouncePixels }, this.bounceDelay);
    }
  },

  bounceRight($elem) {
    for (var i = 0; i < 5; i++) {
      $elem.animate({ right: '-=' + this.bouncePixels }, this.bounceDelay).animate({ right: '+=' + this.bouncePixels }, this.bounceDelay);
    }
  }
});
