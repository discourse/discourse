
/* This class replaces a containerView of many buttons, which was responsible for 100ms
*/


/* of client rendering or so on a fast computer. It might be slightly uglier, but it's
*/


/* _much_ faster.
*/


(function() {

  window.Discourse.PostMenuView = Ember.View.extend(Discourse.Presence, {
    tagName: 'section',
    classNames: ['post-menu-area', 'clearfix'],
    /* Delegate to render#{button}
    */

    render: function(buffer) {
      var post,
        _this = this;
      post = this.get('post');
      this.renderReplies(post, buffer);
      buffer.push("<nav class='post-controls'>");
      Discourse.get('postButtons').forEach(function(button) {
        var _name;
        return typeof _this[_name = "render" + button] === "function" ? _this[_name](post, buffer) : void 0;
      });
      return buffer.push("</nav>");
    },
    /* Delegate click actions
    */

    click: function(e) {
      var $target, action, _name;
      $target = jQuery(e.target);
      action = $target.data('action') || $target.parent().data('action');
      if (!action) {
        return;
      }
      return typeof this[_name = "click" + (action.capitalize())] === "function" ? this[_name]() : void 0;
    },
    /* Trigger re rendering
    */

    needsToRender: (function() {
      return this.rerender();
    }).observes('post.deleted_at', 'post.flagsAvailable.@each', 'post.url', 'post.bookmarked', 'post.reply_count', 'post.showRepliesBelow', 'post.can_delete'),
    /* Replies Button
    */

    renderReplies: function(post, buffer) {
      var icon, reply_count;
      if (!post.get('showRepliesBelow')) {
        return;
      }
      reply_count = post.get('reply_count');
      buffer.push("<button class='show-replies' data-action='replies'>");
      buffer.push("<span class='badge-posts'>" + reply_count + "</span>");
      buffer.push(Em.String.i18n("post.has_replies", {
        count: reply_count
      }));
      icon = this.get('postView.repliesShown') ? 'icon-chevron-up' : 'icon-chevron-down';
      return buffer.push("<i class='icon " + icon + "'></i></button>");
    },
    clickReplies: function() {
      return this.get('postView').showReplies();
    },
    /* Delete button
    */

    renderDelete: function(post, buffer) {
      if (post.get('post_number') === 1 && this.get('controller.content.can_delete')) {
        buffer.push("<button title=\"" + 
                    (Em.String.i18n("topic.actions.delete")) + 
                    "\" data-action=\"deleteTopic\"><i class=\"icon-trash\"></i></button>");
        return;
      }
      /* Show the correct button
      */

      if (post.get('deleted_at')) {
        if (post.get('can_recover')) {
          return buffer.push("<button title=\"" + 
                              (Em.String.i18n("post.controls.undelete")) + 
                              "\" data-action=\"recover\" class=\"delete\"><i class=\"icon-undo\"></i></button>");
        }
      } else if (post.get('can_delete')) {
        return buffer.push("<button title=\"" + 
                           (Em.String.i18n("post.controls.delete")) + 
                           "\" data-action=\"delete\" class=\"delete\"><i class=\"icon-trash\"></i></button>");
      }
    },
    clickDeleteTopic: function() {
      return this.get('controller').deleteTopic();
    },
    clickRecover: function() {
      return this.get('controller').recoverPost(this.get('post'));
    },
    clickDelete: function() {
      return this.get('controller').deletePost(this.get('post'));
    },
    /* Like button
    */

    renderLike: function(post, buffer) {
      if (!post.get('actionByName.like.can_act')) {
        return;
      }
      return buffer.push("<button title=\"" + 
                         (Em.String.i18n("post.controls.like")) + 
                         "\" data-action=\"like\" class='like'><i class=\"icon-heart\"></i></button>");
    },
    clickLike: function() {
      var _ref;
      return (_ref = this.get('post.actionByName.like')) ? _ref.act() : void 0;
    },
    /* Flag button
    */

    renderFlag: function(post, buffer) {
      if (!this.present('post.flagsAvailable')) {
        return;
      }
      return buffer.push("<button title=\"" + 
                         (Em.String.i18n("post.controls.flag")) + 
                         "\" data-action=\"flag\"><i class=\"icon-flag\"></i></button>");
    },
    clickFlag: function() {
      return this.get('controller').showFlags(this.get('post'));
    },
    /* Edit button
    */

    renderEdit: function(post, buffer) {
      if (!post.get('can_edit')) {
        return;
      }
      return buffer.push("<button title=\"" + 
                         (Em.String.i18n("post.controls.edit")) + 
                         "\" data-action=\"edit\"><i class=\"icon-pencil\"></i></button>");
    },
    clickEdit: function() {
      return this.get('controller').editPost(this.get('post'));
    },
    /* Share button
    */

    renderShare: function(post, buffer) {
      return buffer.push("<button title=\"" + 
                         (Em.String.i18n("post.controls.share")) + 
                         "\" data-share-url=\"" + (post.get('url')) + "\"><i class=\"icon-link\"></i></button>");
    },
    /* Reply button
    */

    renderReply: function(post, buffer) {
      if (!this.get('controller.content.can_create_post')) {
        return;
      }
      return buffer.push("<button title=\"" + 
                         (Em.String.i18n("post.controls.reply")) + 
                         "\" class='create' data-action=\"reply\"><i class='icon-reply'></i>" + 
                         (Em.String.i18n("topic.reply.title")) + "</button>");
    },
    clickReply: function() {
      return this.get('controller').replyToPost(this.get('post'));
    },
    /* Bookmark button
    */

    renderBookmark: function(post, buffer) {
      var icon;
      if (!Discourse.get('currentUser')) {
        return;
      }
      icon = 'bookmark';
      if (!this.get('post.bookmarked')) {
        icon += '-empty';
      }
      return buffer.push("<button title=\"" + 
                         (Em.String.i18n("post.controls.bookmark")) + 
                         "\" data-action=\"bookmark\"><i class=\"icon-" + icon + "\"></i></button>");
    },
    clickBookmark: function() {
      return this.get('post').toggleProperty('bookmarked');
    }
  });

}).call(this);
