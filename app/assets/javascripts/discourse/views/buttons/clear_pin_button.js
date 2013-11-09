/**
  A button for clearing a pinned topic

  @class ClearPinButton
  @extends Discourse.ButtonView
  @namespace Discourse
  @module Discourse
**/
Discourse.ClearPinButton = Discourse.ButtonView.extend({
  textKey: 'topic.clear_pin.title',
  helpKey: 'topic.clear_pin.help',
  classNameBindings: ['unpinned'],

  // Hide the button if it becomes unpinned
  unpinned: function() {
    // When not logged in don't show the button
    if (!Discourse.User.current()) return 'hidden';
    return this.get('controller.pinned') ? null : 'hidden';
  }.property('controller.pinned'),

  click: function(buffer) {
    this.get('controller').send('clearPin');
  },

  renderIcon: function(buffer) {
    buffer.push("<i class='icon icon-pushpin'></i>");
  }
});

