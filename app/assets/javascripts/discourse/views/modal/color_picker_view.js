/**
 This view shows an array of buttons for selection of a color from a predefined set.

 @class ColorPickerView
 @extends Discourse.ContainerView
 @namespace Discourse
 @module Discourse
 **/
Discourse.ColorPickerView = Discourse.ContainerView.extend({
  classNames: 'colors-container',

  init: function() {
    this._super();
    return this.createButtons();
  },

  createButtons: function() {
    var colors = this.get('colors');
    var colorPickerView = this;
    var isUsed, usedColors = this.get('usedColors') || [];

    if (!colors) return;

    colors.forEach(function(color) {
      isUsed = usedColors.indexOf(color.toUpperCase()) >= 0;

      colorPickerView.attachViewWithArgs({
        tagName: 'button',
        attributeBindings: ['style', 'title'],
        classNames: ['colorpicker'].concat( isUsed ? ['used-color'] : ['unused-color'] ),
        style: 'background-color: #' + color + ';',
        title: isUsed ? I18n.t("category.already_used") : null,
        click: function() {
          colorPickerView.set("value", color);
          return false;
        }
      });

    });
  }
});

Discourse.View.registerHelper('colorPicker', Discourse.ColorPickerView);
