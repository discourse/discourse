/**
  A button for favoriting a topic

  @class FavoriteButton
  @extends Discourse.ButtonView
  @namespace Discourse
  @module Discourse
**/
Discourse.FavoriteButton = Discourse.ButtonView.extend({
  classNames: ['favorite'],
  textKey: 'favorite.title',
  helpKeyBinding: 'controller.favoriteTooltipKey',
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

