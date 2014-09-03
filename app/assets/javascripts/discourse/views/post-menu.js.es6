// Helper class for rendering a button
export var Button = function(action, label, icon, opts) {
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
  var opts = this.opts;

  buffer.push("<button title=\"" + I18n.t(this.label) + "\"");
  if (opts.disabled) { buffer.push(" disabled"); }
  if (opts.className) { buffer.push(" class=\"" + opts.className + "\""); }
  if (opts.shareUrl) { buffer.push(" data-share-url=\"" + opts.shareUrl + "\""); }
  if (opts.postNumber) { buffer.push(" data-post-number=\"" + opts.postNumber + "\""); }
  buffer.push(" data-action=\"" + this.action + "\">");
  if (this.icon) { buffer.push("<i class=\"fa fa-" + this.icon + "\"></i>"); }
  if (opts.textLabel) { buffer.push(I18n.t(opts.textLabel)); }
  if (opts.innerHTML) { buffer.push(opts.innerHTML); }
  buffer.push("</button>");
};

/**
 * Check whether, given the post object, the Button should render on that post
 * despite it possibly being in the hidden-buttons site setting.
 *
 * Replace this with a function (button.shouldAlwaysShow =
 * function(post) { .... }) following the above contract, or call
 * addAlwaysShowCondition, which will replace it for you, and 'or' the result
 * of your function with any function that was there previously.
 *
 * @param post the post object
 * @returns {boolean} true if the hidden buttons site setting is overridden
 */
Button.prototype.shouldAlwaysShow = false;

/**
 * Add a condition to the shouldAlwaysShow() function.
 *
 * @param callback your function. 'this' is the Button, argument is the post object
 * @returns {Button} the button you called this method on
 */
Button.prototype.addAlwaysShowCondition = function(callback) {
  var previous = this.shouldAlwaysShow;

  if (previous) {
    this.shouldAlwaysShow = function(post) {
      if (callback(post)) return true;
      return previous.call(this, post);
    };
  } else {
    this.shouldAlwaysShow = callback;
  }

  return this;
};

var PostMenuView = Discourse.View.extend({
  tagName: 'section',
  classNames: ['post-menu-area', 'clearfix'],

  // TODO add extension point for plugins adding extra rerender conditions
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
    // anons get no buttons, so don't bother doing anything at all
    if (!Discourse.User.current() && PostMenuView.noButtonsForAnons) {
      return;
    }

    var self = this,
        allButtons = [],
        visibleButtons = [],
        hiddenButtonNames = PostMenuView.hiddenButtons();

    // Create button objects
    PostMenuView.buttonOrder().forEach(function(i) {
      var creator = self["buttonFor" + i.replace(/\+/, '').capitalize()];
      if (creator) {
        var button = creator.call(self, post);
        if (button) {
          allButtons.push(button);
        }
      } else {
        PostMenuView.warnUnknownButtonName(i);
      }
    });

    // Fill in visibleButtons
    if (this.get('collapsed')) {
      allButtons.forEach(function(b) {
        if ((b.shouldAlwaysShow !== false && b.shouldAlwaysShow(post)) ||
            hiddenButtonNames.indexOf(b.action) === -1) {
          visibleButtons.push(b);
        }
      });
      // Only show ellipsis if there is more than one button hidden
      if (allButtons.length <= visibleButtons.length + 1) {
        visibleButtons = allButtons;
      }
    } else {
      visibleButtons = allButtons;
    }

    // remove showMore if only thing left
    if (visibleButtons === ['showMoreActions']) {
      visibleButtons = [];
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
    var likeAction = post.get('actionByName.like');
    if (!likeAction) { return; }

    var className = likeAction.get('acted') ? 'has-like' : 'like';
    if (likeAction.get('canToggle')) {
      var descKey = likeAction.get('acted') ? 'post.controls.undo_like' : 'post.controls.like';
      return new Button('like', descKey, 'heart', {className: className});
    } else if (likeAction.get('acted')) {
      return new Button('like', 'post.controls.has_liked', 'heart', {className: className, disabled: true});
    }
  },

  clickLike: function(post) {
    this.get('controller').send('toggleLike', post);
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
    var button = new Button('edit', 'post.controls.edit', 'pencil', {});
    button.shouldAlwaysShow = function(post) {
          return post.get('wiki') || post.get('yours');
        };
    return button;
  },

  clickEdit: function(post) {
    this.get('controller').send('editPost', post);
  },

  // Share button
  buttonForShare: function(post) {
    if (!Discourse.User.current()) return;
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
    if (!this.get('collapsed')) return;

    return new Button('showMoreActions', 'show_more', 'ellipsis-h');
  },

  clickShowMoreActions: function() {
    this.set('collapsed', false);
  }

});

PostMenuView.reopenClass({
  _hiddenButtons: null,
  hiddenButtons: function() {
    if (!this._hiddenButtons) {
      if (!Em.isEmpty(Discourse.SiteSettings.post_menu_hidden_items)) {
        this._hiddenButtons = Discourse.SiteSettings.post_menu_hidden_items.split('|');
      } else {
        this._hiddenButtons = [];
      }
    }
    return this._hiddenButtons;
  },

  _buttonOrder: null,
  /**
   * Get the order of Buttons in the post menu (as strings)
   *
   * @returns {Array} order of buttons, as strings
   */
  buttonOrder: function() {
    if (this._buttonOrder) return this._buttonOrder;

    var order = Discourse.SiteSettings.post_menu.split("|");

    // Substitute '...' with showMoreActions
    var ellipsisIndex = order.indexOf('...');
    if (ellipsisIndex !== -1) {
      order[ellipsisIndex] = 'showMoreActions';
    }

    // Put showMore right before end if it isn't there
    ellipsisIndex = order.indexOf('showMoreActions');
    if (ellipsisIndex === -1) {
      order.splice(order.length - 1, 0, 'showMoreActions');
    }


    return this._buttonOrder = order;
  },

  /**
   * PLUGINS - change this to false if you need anons to have a button!
   */
  noButtonsForAnons: true,

  warnedNames: [],
  warnUnknownButtonName: function(buttonName) {
    var warnedButtons = this.get('warnedNames');
    if (warnedButtons.indexOf(buttonName) === -1) {
      Em.Logger.warn("Unknown post menu button type " + buttonName + " - please fix the post_menu site setting");
      warnedButtons.push(buttonName);
    }
  }
});

export default PostMenuView;
