/**
  An input field for a color.

  @param hexValue is a reference to the color's hex value.

  @class Discourse.ColorInputComponent
  @extends Ember.Component
  @namespace Discourse
  @module Discourse
 **/
Discourse.ColorInputComponent = Ember.Component.extend({
  layoutName: 'components/color-input',

  hexValueChanged: function() {
    var hex = this.get('hexValue');
    if (hex && (hex.length === 3 || hex.length === 6) && this.get('brightnessValue')) {
      this.$('input').attr('style', 'color: ' + (this.get('brightnessValue') > 125 ? 'black' : 'white') + '; background-color: #' + hex + ';');
    }
  }.observes('hexValue', 'brightnessValue'),

  didInsertElement: function() {
    var self = this;
    this._super();
    Em.run.schedule('afterRender', function() {
      self.hexValueChanged();
    });
  }
});
