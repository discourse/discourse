/**
  This view extends the functionality of InputTipView with these extra features:
    * it can be dismissed
    * it bounces when it's shown
    * it's absolutely positioned beside the input element, with the help of
      extra css you'll need to write to line it up correctly.

  @class PopupInputTipView
  @extends Discourse.View
  @namespace Discourse
  @module Discourse
**/
Discourse.PopupInputTipView = Discourse.View.extend({
  templateName: 'popup_input_tip',
  classNameBindings: [':popup-tip', 'good', 'bad', 'shownAt::hide'],
  animateAttribute: null,
  bouncePixels: 6,
  bounceDelay: 100,

  click: function(e) {
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

  bounceLeft: function($elem) {
    for( var i = 0; i < 5; i++ ) {
      $elem.animate({ left: '+=' + this.bouncePixels }, this.bounceDelay).animate({ left: '-=' + this.bouncePixels }, this.bounceDelay);
    }
  },

  bounceRight: function($elem) {
    for( var i = 0; i < 5; i++ ) {
      $elem.animate({ right: '-=' + this.bouncePixels }, this.bounceDelay).animate({ right: '+=' + this.bouncePixels }, this.bounceDelay);
    }
  }
});

Discourse.View.registerHelper('popupInputTip', Discourse.PopupInputTipView);