/**
  An input field for a color.

  @param hexValue is a reference to the color's hex value.
  @param brightnessValue is a number from 0 to 255 representing the brightness of the color. See ColorSchemeColor.
  @params valid is a boolean indicating if the input field is a valid color.

  @class Discourse.ColorInputComponent
  @extends Ember.Component
  @namespace Discourse
  @module Discourse
 **/
Discourse.ColorInputComponent = Ember.Component.extend({
  layoutName: 'components/color-input',

  hexValueChanged: function() {
    var hex = this.get('hexValue');
    if (this.get('valid')) {
      this.$('input').attr('style', 'color: ' + (this.get('brightnessValue') > 125 ? 'black' : 'white') + '; background-color: #' + hex + ';');
    } else {
      this.$('input').attr('style', '');
    }
  }.observes('hexValue', 'brightnessValue', 'valid'),

  didInsertElement: function() {
    var self = this;
    this._super();
    Em.run.schedule('afterRender', function() {
      self.hexValueChanged();
    });
  }
});
