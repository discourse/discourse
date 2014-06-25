/**
  This view renders a menu below a post. It uses buffered rendering for performance.

  @class PostMenuView
  @extends Discourse.View
  @namespace Discourse
  @module Discourse
**/

// Helper class for rendering a button
var Button = function(action, label, icon, opts) {
  this.action = action;
  this.label = label;

  if (typeof icon === "object") {
    this.opts = icon;
  } else {
    this.icon = icon;
  }
  this.opts = this.opts || opts || {};
};

Button.prototype.render = function(buffer) {
  buffer.push("<button title=\"" + I18n.t(this.label) + "\"");
  if (this.opts.className) { buffer.push(" class=\"" + this.opts.className + "\""); }
  if (this.opts.shareUrl) { buffer.push(" data-share-url=\"" + this.opts.shareUrl + "\""); }
  if (this.opts.postNumber) { buffer.push(" data-post-number=\"" + this.opts.postNumber + "\""); }
  buffer.push(" data-action=\"" + this.action + "\">");
  if (this.icon) { buffer.push("<i class=\"fa fa-" + this.icon + "\"></i>"); }
  if (this.opts.textLabel) { buffer.push(I18n.t(this.opts.textLabel)); }
  if (this.opts.innerHTML) { buffer.push(this.opts.innerHTML); }
  buffer.push("</button>");
};

var hiddenButtons;

export default Discourse.View.extend({
  tagName: 'section',
  classNames: ['post-menu-area', 'clearfix'],

  shouldRerender: Discourse.View.renderIfChanged(
    'post.deleted_at',
    'post.flagsAvailable.@each',
    'post.reply_count',
    'post.showRepliesBelow',
    'post.can_delete',
    'post.bookmarked',
    'post.shareUrl',
    'post.topic.deleted_at',
    'post.replies.length',
    'post.wiki',
    'collapsed'),

  _collapsedByDefault: function() {
    this.set('collapsed', true);
  }.on('init'),

  render: function(buffer) {
    var post = this.get('post');

    buffer.push("<nav class='post-controls'>");
    this.renderReplies(post, buffer);
    this.renderButtons(post, buffer);
    this.renderAdminPopup(post, buffer);
    buffer.push("</nav>");
  },

  // Delegate click actions
  click: function(e) {
    var $target = $(e.target),
        action = $target.data('action') || $target.parent().data('action');

    if (!action) return;
    var handler = this["click" + action.capitalize()];
    if (!handler) return;

    handler.call(this, this.get('post'));
  },

  // Replies Button
  renderReplies: function(post, buffer) {
    if (!post.get('showRepliesBelow')) return;

    var reply_count = post.get('reply_count');
    buffer.push("<button class='show-replies' data-action='replies'>");
    buffer.push("<span class='badge-posts'>" + reply_count + "</span>");
    buffer.push(I18n.t("post.has_replies", { count: reply_count }));

    var icon = (this.get('post.replies.length') > 0) ? 'fa-chevron-up' : 'fa-chevron-down';
    return buffer.push("<i class='fa " + icon + "'></i></button>");
  },

  renderButtons: function(post, buffer) {
    var self = this,
        allButtons = [],
        visibleButtons = [];

    if (typeof hiddenButtons === "undefined") {
      if (!Em.isEmpty(Discourse.SiteSettings.post_menu_hidden_items)) {
        hiddenButtons = Discourse.SiteSettings.post_menu_hidden_items.split('|');
      } else {
        hiddenButtons = [];
      }
    }

    var yours = post.get('yours');
    Discourse.SiteSettings.post_menu.split("|").forEach(function(i) {
      var creator = self["buttonFor" + i.replace(/\+/, '').capitalize()];
      if (creator) {
        var button = creator.call(self, post);
        if (button) {
          allButtons.push(button);
          if ((yours && button.opts.alwaysShowYours) ||
              (post.get('wiki') && button.opts.alwaysShowWiki) ||
              (hiddenButtons.indexOf(i) === -1)) {
            visibleButtons.push(button);
          }
        }
      }
    });

    // Only show ellipsis if there is more than one button hidden
    if (!this.get('collapsed') || (allButtons.length <= visibleButtons.length + 1)) {
      visibleButtons = allButtons;
    } else {
      visibleButtons.splice(visibleButtons.length - 1, 0, this.buttonForShowMoreActions(post));
    }

    buffer.push('<div class="actions">');
    visibleButtons.forEach(function (b) {
      b.render(buffer);
    });
    buffer.push("</div>");
  },

  clickReplies: function() {
    if (this.get('post.replies.length') > 0) {
      this.set('post.replies', []);
    } else {
      this.get('post').loadReplies();
    }
  },

  // Delete button
  buttonForDelete: function(post) {
    var label, icon;

    if (post.get('post_number') === 1) {
      // If it's the first post, the delete/undo actions are related to the topic
      var topic = post.get('topic');
      if (topic.get('deleted_at')) {
        if (!topic.get('details.can_recover')) { return; }
        label = "topic.actions.recover";
        icon = "undo";
      } else {
        if (!topic.get('details.can_delete')) { return; }
        label = "topic.actions.delete";
        icon = "trash-o";
      }

    } else {
      // The delete actions target the post iteself
      if (post.get('deleted_at') || post.get('user_deleted')) {
        if (!post.get('can_recover')) { return; }
        label = "post.controls.undelete";
        icon = "undo";
      } else {
        if (!post.get('can_delete')) { return; }
        label = "post.controls.delete";
        icon = "trash-o";
      }
    }
    var action = (icon === 'trash-o') ? 'delete' : 'recover';
    var opts;
    if (icon === "trash-o"){
      opts = {className: 'delete'};
    }
    return new Button(action, label, icon, opts);
  },

  clickRecover: function(post) {
    this.get('controller').send('recoverPost', post);
  },

  clickDelete: function(post) {
    this.get('controller').send('deletePost', post);
  },

  // Like button
  buttonForLike: function(post) {
    if (!post.get('actionByName.like.can_act')) return;
    return new Button('like', 'post.controls.like', 'heart', {className: 'like'});
  },

  clickLike: function(post) {
    this.get('controller').send('likePost', post);
  },

  // Flag button
  buttonForFlag: function(post) {
    if (Em.isEmpty(post.get('flagsAvailable'))) return;
    return new Button('flag', 'post.controls.flag', 'flag');
  },

  clickFlag: function(post) {
    this.get('controller').send('showFlags', post);
  },

  // Edit button
  buttonForEdit: function(post) {
    if (!post.get('can_edit')) return;
    return new Button('edit', 'post.controls.edit', 'pencil', {
      alwaysShowYours: true,
      alwaysShowWiki: true
    });
  },

  clickEdit: function(post) {
    this.get('controller').send('editPost', post);
  },

  // Share button
  buttonForShare: function(post) {
    var options = {
      shareUrl: post.get('shareUrl'),
      postNumber: post.get('post_number')
    };
    return new Button('share', 'post.controls.share', 'link', options);
  },

  // Reply button
  buttonForReply: function() {
    if (!this.get('controller.model.details.can_create_post')) return;
    var options = {className: 'create'};

    if(!Discourse.Mobile.mobileView) {
      options.textLabel = 'topic.reply.title';
    }

    return new Button('reply', 'post.controls.reply', 'reply', options);
  },

  clickReply: function(post) {
    this.get('controller').send('replyToPost', post);
  },

  // Bookmark button
  buttonForBookmark: function(post) {
    if (!Discourse.User.current()) return;

    var iconClass = 'read-icon',
        buttonClass = 'bookmark',
        tooltip = 'bookmarks.not_bookmarked';

    if (post.get('bookmarked')) {
      iconClass += ' bookmarked';
      buttonClass += ' bookmarked';
      tooltip = 'bookmarks.created';
    }

    return new Button('bookmark', tooltip, {className: buttonClass, innerHTML: "<div class='" + iconClass + "'>"});
  },

  clickBookmark: function(post) {
    this.get('controller').send('toggleBookmark', post);
  },

  buttonForAdmin: function() {
    if (!Discourse.User.currentProp('canManageTopic')) { return; }
    return new Button('admin', 'post.controls.admin', 'wrench');
  },

  renderAdminPopup: function(post, buffer) {
    if (!Discourse.User.currentProp('canManageTopic')) { return; }
    var wikiText = post.get('wiki') ? I18n.t('post.controls.unwiki') : I18n.t('post.controls.wiki');
    buffer.push('<div class="post-admin-menu"><h3>' + I18n.t('admin_title') + '</h3><ul><li class="btn btn-admin" data-action="toggleWiki"><i class="fa fa-pencil-square-o"></i>' + wikiText +'</li></ul></div>');
  },

  clickAdmin: function() {
    var $adminMenu = this.$('.post-admin-menu');
    this.set('adminMenu', $adminMenu);
    $adminMenu.show();
  },

  clickToggleWiki: function() {
    this.get('controller').send('toggleWiki', this.get('post'));
  },

  buttonForShowMoreActions: function() {
    return new Button('showMoreActions', 'show_more', 'ellipsis-h');
  },

  clickShowMoreActions: function() {
    this.set('collapsed', false);
  }

});
