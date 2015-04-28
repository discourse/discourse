import { iconHTML } from 'discourse/helpers/fa-icon';

export default Ember.Component.extend({
  classNameBindings: [':popup-tip', 'good', 'bad', 'shownAt::hide'],
  animateAttribute: null,
  bouncePixels: 6,
  bounceDelay: 100,

  click() {
    this.set('shownAt', false);
  },

  good: function() {
    return !this.get('validation.failed');
  }.property('validation'),

  bad: function() {
    return this.get('validation.failed');
  }.property('validation'),

  bounce: function() {
    if( this.get('shownAt') ) {
      var $elem = this.$();
      if( !this.animateAttribute ) {
        this.animateAttribute = $elem.css('left') === 'auto' ? 'right' : 'left';
      }
      if( this.animateAttribute === 'left' ) {
        this.bounceLeft($elem);
      } else {
        this.bounceRight($elem);
      }
    }
  }.observes('shownAt'),

  render(buffer) {
    const reason = this.get('validation.reason');
    if (!reason) { return; }

    buffer.push("<span class='close'>" + iconHTML('times-circle') + "</span>");
    buffer.push(reason);
  },

  bounceLeft($elem) {
    for( var i = 0; i < 5; i++ ) {
      $elem.animate({ left: '+=' + this.bouncePixels }, this.bounceDelay).animate({ left: '-=' + this.bouncePixels }, this.bounceDelay);
    }
  },

  bounceRight($elem) {
    for( var i = 0; i < 5; i++ ) {
      $elem.animate({ right: '-=' + this.bouncePixels }, this.bounceDelay).animate({ right: '+=' + this.bouncePixels }, this.bounceDelay);
    }
  }
});
