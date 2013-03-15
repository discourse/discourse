/**
 This view shows an array of buttons for selection of a color from a predefined set.

 @class ColorsView
 @extends Ember.ContainerView
 @namespace Discourse
 @module Discourse
 **/
Discourse.ColorsView = Ember.ContainerView.extend({
    classNames: 'colors-container',

    init: function() {
        this._super();
        return this.createButtons();
    },

    createButtons: function() {
        var colors = this.get('colors');
        var _this = this;

        colors.each(function(color) {
            _this.addObject(Discourse.View.create({
                tagName: 'button',
                attributeBindings: ['style'],
                classNames: ['colorpicker'],
                style: 'background-color: #' + color + ';',
                click: function() {
                    _this.set("value", color);
                    return false;
                }
            }));
        });
    }
});
