/**
  This view renders a link within a post

  @class PostLinkView
  @extends Discourse.View
  @namespace Discourse
  @module Discourse
**/
Discourse.PostLinkView = Discourse.View.extend({
  tagName: 'li',

  direction: function() { return this.get('content.reflection') ? "left" : "right"; },

  render: function(buffer) {
    var clicks;
    buffer.push("<a href='" + this.get('content.url') + "' class='track-link'>");
    buffer.push("<i class='icon icon-arrow-" + this.direction() + "'></i>");
    buffer.push(this.get('content.title'));
    if (clicks = this.get('content.clicks')) {
      buffer.push("<span class='badge badge-notification clicks'>" + clicks + "</span>");
    }
    buffer.push("</a>");
  }
});
