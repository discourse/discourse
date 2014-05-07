var MAX_SHOWN = 5;

Discourse.PostLinksComponent = Em.Component.extend({
  tagName: 'ul',
  classNameBindings: [':post-links'],

  render: function(buffer) {
    var links = this.get('links'),
        toRender = links;

    if (Em.isEmpty(links)) { return; }

    if (!this.get('expanded')) {
      toRender = toRender.slice(0, MAX_SHOWN);
    }

    toRender.forEach(function(l) {
      var direction = Em.get(l, 'reflection') ? 'left' : 'right',
          clicks = Em.get(l, 'clicks');

      buffer.push("<li><a href='" + Em.get(l, 'url') + "' class='track-link'>");
      buffer.push("<i class='fa fa-arrow-" + direction + "'></i>");
      buffer.push(Em.get(l, 'title'));
      if (clicks) {
        buffer.push("<span class='badge badge-notification clicks'>" + clicks + "</span>");
      }
      buffer.push("</a></li>");
    });

    if (!this.get('expanded')) {
      var remaining = links.length - MAX_SHOWN;
      if (remaining > 0) {
        buffer.push("<li><a href='#' class='toggle-more'>" + I18n.t('post.more_links', {count: remaining}) + "</a></li>");
      }
    }
  },

  _rerenderIfNeeded: function() {
    this.rerender();
  }.observes('expanded'),

  click: function(e) {
    if ($(e.target).hasClass('toggle-more')) {
      this.toggleProperty('expanded');
      return false;
    }
    return true;
  }
});
