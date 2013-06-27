/**
  A button for favoriting a topic

  @class FavoriteButton
  @extends Discourse.ButtonView
  @namespace Discourse
  @module Discourse
**/
Discourse.FavoriteButton = Discourse.ButtonView.extend({
  textKey: 'favorite.title',
  helpKeyBinding: 'controller.content.favoriteTooltipKey',

  favoriteChanged: function() {
    this.rerender();
  }.observes('controller.content.starred'),

  click: function() {
    this.get('controller').toggleStar();
  },

  renderIcon: function(buffer) {
    buffer.push("<i class='icon-star " +
                 (this.get('controller.content.starred') ? ' starred' : '') +
                 "'></i>");
  }
});

