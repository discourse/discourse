/**
 This view shows an array of buttons for selection of a color from a predefined set.

 @class ColorPickerView
 @extends Ember.ContainerView
 @namespace Discourse
 @module Discourse
 **/
Discourse.ColorPickerView = Ember.ContainerView.extend({
  classNames: 'colors-container',

  init: function() {
    this._super();
    return this.createButtons();
  },

  createButtons: function() {
    var colors = this.get('colors');
    var _this = this;
    var isUsed, usedColors = this.get('usedColors') || [];

    colors.each(function(color) {
      isUsed = usedColors.indexOf(color.toUpperCase()) >= 0;
      _this.addObject(Discourse.View.create({
        tagName: 'button',
        attributeBindings: ['style', 'title'],
        classNames: ['colorpicker'].concat( isUsed ? ['used-color'] : ['unused-color'] ),
        style: 'background-color: #' + color + ';',
        title: isUsed ? I18n.t("js.category.already_used") : null,
        click: function() {
          _this.set("value", color);
          return false;
        }
      }));
    });
  }
});

Discourse.View.registerHelper('colorPicker', Discourse.ColorPickerView);