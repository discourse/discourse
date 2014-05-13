var PosterNameComponent = Em.Component.extend({
  classNames: ['names'],
  displayNameOnPosts: Discourse.computed.setting('display_name_on_posts'),

  render: function(buffer) {
    var post = this.get('post');

    if (post) {
      var name = post.get('name'),
          username = post.get('username'),
          linkClass = 'username';

      if (post.get('staff')) { linkClass += ' staff'; }
      if (post.get('new_user')) { linkClass += ' new-user'; }

      // Main link
      buffer.push("<span class='" + linkClass + "'><a href='#'>" + username + "</a>");

      // Add a glyph if we have one
      var glyph = this.posterGlyph(post);
      if (!Em.isEmpty(glyph)) {
        buffer.push("<i class='fa fa-" + glyph + "'></i>");
      }
      buffer.push("</span>");

      // Are we showing full names?
      if (name && (name === username) && this.get('displayNameOnPosts')) {
        buffer.push("<span class='full-name'><a href='#'>" + name + "</a></span>");
      }

      // User titles
      var title = post.get('user_title');
      if (!Em.isEmpty(title)) {
        var primaryGroupName = post.get('primary_group_name');

        buffer.push('<span class="user-title">');
        if (Em.isEmpty(primaryGroupName)) {
          buffer.push(title);
        } else {
          buffer.push("<a href='#' class='user-group'>" + title + "</a>");
        }
        buffer.push("</span>");
      }

      PosterNameComponent.trigger('renderedName', buffer);
    }
  },

  click: function(e) {
    var $target = $(e.target);
    if ($target.hasClass('user-group')) {
      Discourse.URL.routeTo("/groups/" + this.get('post.primary_group_name'));
    } else {
      this.sendAction('expandAction', this.get('post'));
    }
    return false;
  },

  /**
    Overwrite this to give a user a custom font awesome glyph.

    @method posterGlyph
    @param {Post} the related post.
    @return {String} the glyph to render (or null for none)
  **/
  posterGlyph: function(post) {
    if (post.get('admin')) {
      return 'trophy';
    } else if (post.get('moderator')) {
      return 'magic';
    }
  }
});

// Support for event triggering
PosterNameComponent.reopenClass(Em.Evented);

export default PosterNameComponent;
