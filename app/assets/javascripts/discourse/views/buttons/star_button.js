/**
  A button for starring a topic

  @class StarButton
  @extends Discourse.ButtonView
  @namespace Discourse
  @module Discourse
**/
Discourse.StarButton = Discourse.ButtonView.extend({
  classNames: ['star'],
  textKey: 'starred.title',
  helpKeyBinding: 'controller.starTooltipKey',
  attributeBindings: ['disabled'],

  shouldRerender: Discourse.View.renderIfChanged('controller.starred'),

  click: function() {
    this.get('controller').send('toggleStar');
  },

  renderIcon: function(buffer) {
    buffer.push("<i class='fa fa-star " +
                 (this.get('controller.starred') ? ' starred' : '') +
                 "'></i>");
  }
});

