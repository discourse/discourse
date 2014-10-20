var PosterNameComponent = Em.Component.extend({
  classNames: ['names', 'trigger-user-card'],
  displayNameOnPosts: Discourse.computed.setting('display_name_on_posts'),

  // sanitize name for comparison
  sanitizeName: function(name){
    return name.toLowerCase().replace(/[\s_-]/g,'');
  },

  render: function(buffer) {
    var post = this.get('post');

    if (post) {
      var name = post.get('name'),
          username = post.get('username'),
          linkClass = 'username',
          primaryGroupName = post.get('primary_group_name'),
          url = post.get('usernameUrl');

      if (post.get('staff')) { linkClass += ' staff'; }
      if (post.get('admin')) { linkClass += ' admin'; }
      if (post.get('moderator')) { linkClass += ' moderator'; }
      if (post.get('new_user')) { linkClass += ' new-user'; }

      if (!Em.isEmpty(primaryGroupName)) {
        linkClass += ' ' + primaryGroupName;
      }
      // Main link
      buffer.push("<span class='" + linkClass + "'><a href='" + url + "' data-auto-route='true'>" + username + "</a>");

      // Add a glyph if we have one
      var glyph = this.posterGlyph(post);
      if (!Em.isEmpty(glyph)) {
        buffer.push(glyph);
      }
      buffer.push("</span>");

      // Are we showing full names?
      if (name && this.get('displayNameOnPosts') && (this.sanitizeName(name) !== this.sanitizeName(username))) {
        name = Handlebars.Utils.escapeExpression(name);
        buffer.push("<span class='full-name'><a href='" + url + "' data-auto-route='true'>" + name + "</a></span>");
      }

      // User titles
      var title = post.get('user_title');
      if (!Em.isEmpty(title)) {

        title = Handlebars.Utils.escapeExpression(title);
        buffer.push('<span class="user-title">');
        if (Em.isEmpty(primaryGroupName)) {
          buffer.push(title);
        } else {
          buffer.push("<a href='/groups/" + post.get('primary_group_name') + "' class='user-group'>" + title + "</a>");
        }
        buffer.push("</span>");
      }

      PosterNameComponent.trigger('renderedName', buffer, post);
    }
  },

  click: function(e) {
    var $target = $(e.target),
        href = $target.attr('href'),
        url = this.get('post.usernameUrl');

    if (!Em.isEmpty(href) && href !== url) {
      return true;
    } else  {
      this.appEvents.trigger('poster:expand', $target);
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
    var desc;

    if(post.get('moderator')) {
      desc = I18n.t('user.moderator_tooltip');
      return '<i class="fa fa-shield" title="' + desc +  '" alt="' + desc + '"></i>';
    }
  }
});

// Support for event triggering
PosterNameComponent.reopenClass(Em.Evented);

export default PosterNameComponent;
