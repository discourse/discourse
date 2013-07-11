/**
  This view handles rendering of a button

  @class ButtonView
  @extends Discourse.View
  @namespace Discourse
  @module Discourse
**/
Discourse.ButtonView = Discourse.View.extend({
  tagName: 'button',
  classNameBindings: [':btn', ':standard', 'dropDownToggle'],
  attributeBindings: ['title', 'data-toggle', 'data-share-url'],

  title: function() {
    return I18n.t(this.get('helpKey') || this.get('textKey'));
  }.property('helpKey'),

  text: function() {
    return I18n.t(this.get('textKey'));
  }.property('textKey'),

  render: function(buffer) {
    if (this.renderIcon) {
      this.renderIcon(buffer);
    }
    buffer.push(this.get('text'));
  }

});


