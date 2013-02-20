(function() {

  window.Discourse.PostLinkView = Ember.View.extend({
    tagName: 'li',
    classNameBindings: ['direction'],
    direction: (function() {
      if (this.get('content.reflection')) {
        return 'incoming';
      }
      return null;
    }).property('content.reflection'),
    render: function(buffer) {
      var clicks;
      buffer.push("<a href='" + (this.get('content.url')) + "' class='track-link'>\n");
      buffer.push("<i class='icon icon-arrow-right'></i>");
      buffer.push(this.get('content.title'));
      if (clicks = this.get('content.clicks')) {
        buffer.push("\n<span class='badge badge-notification clicks'>" + clicks + "</span>");
      }
      return buffer.push("</a>");
    }
  });

}).call(this);
