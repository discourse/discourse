import StringBuffer from 'discourse/mixins/string-buffer';
import { iconHTML } from 'discourse/helpers/fa-icon';

// Helper class for rendering a button
export const Button = function(action, label, icon, opts) {
  this.action = action;
  this.label = label;

  if (typeof icon === "object") {
    this.opts = icon;
  } else {
    this.icon = icon;
  }
  this.opts = this.opts || opts || {};
};

function animateHeart($elem, start, end, complete) {
  if (Ember.testing) { return Ember.run(this, complete); }

  $elem.stop()
       .css('textIndent', start)
       .animate({ textIndent: end }, {
          complete,
          step(now) {
            $(this).css('transform','scale('+now+')');
          },
          duration: 150
        }, 'linear');
}

Button.prototype.render = function(buffer) {
  const opts = this.opts;

  const label = I18n.t(this.label, opts.labelOptions);
  if (opts.prefixHTML) {
    buffer.push(opts.prefixHTML);
  }
  buffer.push("<button aria-label=\"" + label +"\" " + "title=\"" + label + "\"");

  if (opts.disabled) { buffer.push(" disabled"); }
  if (opts.className) { buffer.push(" class=\"" + opts.className + "\""); }
  if (opts.shareUrl) { buffer.push(" data-share-url=\"" + opts.shareUrl + "\""); }
  if (opts.postNumber) { buffer.push(" data-post-number=\"" + opts.postNumber + "\""); }
  buffer.push(" data-action=\"" + this.action + "\">");
  if (this.icon) { buffer.push(iconHTML(this.icon)); }
  if (opts.textLabel) { buffer.push(I18n.t(opts.textLabel)); }
  if (opts.innerHTML) { buffer.push(opts.innerHTML); }
  buffer.push("</button>");
};

let hiddenButtons;

const PostMenuComponent = Ember.Component.extend(StringBuffer, {
  tagName: 'section',
  classNames: ['post-menu-area', 'clearfix'],

  rerenderTriggers: [
    'post.deleted_at',
    'post.likeAction.count',
    'post.likeAction.users.length',
    'post.reply_count',
    'post.showRepliesBelow',
    'post.can_delete',
    'post.bookmarked',
    'post.shareUrl',
    'post.topic.deleted_at',
    'post.replies.length',
    'post.wiki',
    'post.post_type',
    'collapsed'],

  _collapsedByDefault: function() {
    this.set('collapsed', true);
  }.on('init'),

  renderString(buffer) {
    const post = this.get('post');

    buffer.push("<nav class='post-controls'>");
    this.renderReplies(post, buffer);
    this.renderButtons(post, buffer);
    this.renderAdminPopup(post, buffer);
    buffer.push("</nav>");
  },

  // Delegate click actions
  click(e) {
    const $target = $(e.target);
    const action = $target.data('action') || $target.parent().data('action');

    if ($target.prop('disabled') || $target.parent().prop('disabled')) { return; }

    if (!action) return;
    const handler = this["click" + action.classify()];
    if (!handler) return;

    handler.call(this, this.get('post'));
  },

  // Replies Button
  renderReplies(post, buffer) {
    if (!post.get('showRepliesBelow')) return;

    const replyCount = post.get('reply_count');
    buffer.push("<button class='show-replies highlight-action' data-action='replies'>");
    buffer.push(I18n.t("post.has_replies", { count: replyCount || 0 }));

    const icon = (this.get('post.replies.length') > 0) ? 'chevron-up' : 'chevron-down';
    return buffer.push(iconHTML(icon) + "</button>");
  },

  renderButtons(post, buffer) {
    const self = this;
    const allButtons = [];
    let visibleButtons = [];

    if (typeof hiddenButtons === "undefined") {
      if (!Em.isEmpty(this.siteSettings.post_menu_hidden_items)) {
        hiddenButtons = this.siteSettings.post_menu_hidden_items.split('|');
      } else {
        hiddenButtons = [];
      }
    }

    if (post.get("bookmarked")) {
      hiddenButtons.removeObject("bookmark");
    }

    const yours = post.get('yours');
    this.siteSettings.post_menu.split("|").forEach(function(i) {
      const creator = self["buttonFor" + i.classify()];
      if (creator) {
        const button = creator.call(self, post);
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
    // if there are no more buttons, we are not collapsed
    const collapsed = this.get('collapsed');
    if (!collapsed || (allButtons.length <= visibleButtons.length + 1)) {
      visibleButtons = allButtons;
      if (collapsed) { this.set('collapsed', false); }
    } else {
      visibleButtons.splice(visibleButtons.length - 1, 0, this.buttonForShowMoreActions(post));
    }

    const callbacks = PostMenuComponent._registerButtonCallbacks;
    if (callbacks) {
      _.each(callbacks, function(callback) {
        callback.apply(self, [visibleButtons]);
      });
    }

    buffer.push('<div class="actions">');
    visibleButtons.forEach((b) => b.render(buffer));
    buffer.push("</div>");
  },

  clickLikeCount() {
    this.sendActionTarget('toggleWhoLiked');
  },

  sendActionTarget(action, arg) {
    const target = this.get(`${action}Target`);
    return target ? target.send(this.get(action), arg) : this.sendAction(action, arg);
  },

  clickReplies() {
    if (this.get('post.replies.length') > 0) {
      this.set('post.replies', []);
    } else {
      this.get('post').loadReplies();
    }
  },

  // Delete button
  buttonForDelete(post) {
    let label, icon;

    if (post.get('post_number') === 1) {
      // If it's the first post, the delete/undo actions are related to the topic
      const topic = post.get('topic');
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
    const action = (icon === 'trash-o') ? 'delete' : 'recover';
    let opts;
    if (icon === "trash-o"){
      opts = {className: 'delete'};
    }
    return new Button(action, label, icon, opts);
  },

  clickRecover(post) {
    this.sendAction('recoverPost', post);
  },

  clickDelete(post) {
    this.sendAction('deletePost', post);
  },

  // Like button
  buttonForLike() {
    const likeAction = this.get('post.likeAction');
    if (!likeAction) { return; }

    const className = likeAction.get('acted') ? 'has-like fade-out' : 'like';
    const opts = {className: className};

    if (likeAction.get('canToggle')) {
      const descKey = likeAction.get('acted') ? 'post.controls.undo_like' : 'post.controls.like';
      return new Button('like', descKey, 'heart', opts);
    } else if (likeAction.get('acted')) {
      opts.disabled = true;
      return new Button('like', 'post.controls.has_liked', 'heart', opts);
    }
  },

  buttonForLikeCount() {
    const likeCount = this.get('post.likeAction.count') || 0;
    if (likeCount > 0) {
      const likedPost = !!this.get('post.likeAction.acted');

      const label = likedPost ? 'post.has_likes_title_you' : 'post.has_likes_title';

      return new Button('like-count', label, undefined, {
        className: 'like-count highlight-action',
        innerHTML: I18n.t("post.has_likes", { count:  likeCount }),
        labelOptions: {count: likedPost ? (likeCount-1) : likeCount}
      });
    }
  },

  clickLike(post) {
    const $heart = this.$('.fa-heart'),
          $likeButton = this.$('button[data-action=like]'),
          acted = post.get('likeAction.acted'),
          self = this;

    if (acted) {
      this.sendActionTarget('toggleLike');
      $likeButton.removeClass('has-like').addClass('like');
    } else {
      const scale = [1.0, 1.5];
      animateHeart($heart, scale[0], scale[1], function() {
        animateHeart($heart, scale[1], scale[0], function() {
          self.sendActionTarget('toggleLike');
          $likeButton.removeClass('like').addClass('has-like');
        });
      });
    }
  },

  // Flag button
  buttonForFlag(post) {
    if (Em.isEmpty(post.get('flagsAvailable'))) return;
    return new Button('flag', 'post.controls.flag', 'flag');
  },

  clickFlag(post) {
    this.sendAction('showFlags', post);
  },

  // Edit button
  buttonForEdit(post) {
    if (!post.get('can_edit')) return;
    return new Button('edit', 'post.controls.edit', 'pencil', {
      alwaysShowYours: true,
      alwaysShowWiki: true
    });
  },

  clickEdit(post) {
    this.sendAction('editPost', post);
  },

  // Share button
  buttonForShare(post) {
    const options = {
      shareUrl: post.get('shareUrl'),
      postNumber: post.get('post_number')
    };
    return new Button('share', 'post.controls.share', 'link', options);
  },

  // Reply button
  buttonForReply() {
    if (!this.get('canCreatePost')) return;
    const options = {className: 'create fade-out'};

    if(!Discourse.Mobile.mobileView) {
      options.textLabel = 'topic.reply.title';
    }

    return new Button('reply', 'post.controls.reply', 'reply', options);
  },

  clickReply(post) {
    this.sendAction('replyToPost', post);
  },

  // Bookmark button
  buttonForBookmark(post) {
    if (!Discourse.User.current()) return;

    let iconClass = 'read-icon',
        buttonClass = 'bookmark',
        tooltip = 'bookmarks.not_bookmarked';

    if (post.get('bookmarked')) {
      iconClass += ' bookmarked';
      buttonClass += ' bookmarked';
      tooltip = 'bookmarks.created';
    }

    return new Button('bookmark', tooltip, {className: buttonClass, innerHTML: "<div class='" + iconClass + "'>"});
  },

  clickBookmark(post) {
    this.sendAction('toggleBookmark', post);
  },

  buttonForAdmin() {
    if (!Discourse.User.currentProp('canManageTopic')) { return; }
    return new Button('admin', 'post.controls.admin', 'wrench');
  },

  renderAdminPopup(post, buffer) {
    if (!Discourse.User.currentProp('canManageTopic')) { return; }

    const isWiki = post.get('wiki'),
          wikiIcon = iconHTML('pencil-square-o'),
          wikiText = isWiki ? I18n.t('post.controls.unwiki') : I18n.t('post.controls.wiki'),
          isModerator = post.get('post_type') === this.site.get('post_types.moderator_action'),
          postTypeIcon = iconHTML('shield'),
          postTypeText = isModerator ? I18n.t('post.controls.revert_to_regular') : I18n.t('post.controls.convert_to_moderator'),
          rebakePostIcon = iconHTML('cog'),
          rebakePostText = I18n.t('post.controls.rebake'),
          unhidePostIcon = iconHTML('eye'),
          unhidePostText = I18n.t('post.controls.unhide');

    const html = '<div class="post-admin-menu popup-menu">' +
                 '<h3>' + I18n.t('admin_title') + '</h3>' +
                 '<ul>' +
                   '<li class="btn" data-action="toggleWiki">' + wikiIcon + wikiText + '</li>' +
                   (Discourse.User.currentProp('staff') ? '<li class="btn" data-action="togglePostType">' + postTypeIcon + postTypeText + '</li>' : '') +
                   '<li class="btn" data-action="rebakePost">' + rebakePostIcon + rebakePostText + '</li>' +
                   (post.hidden ? '<li class="btn" data-action="unhidePost">' + unhidePostIcon + unhidePostText + '</li>' : '') +
                 '</ul>' +
               '</div>';

    buffer.push(html);
  },

  clickAdmin() {
    const $postAdminMenu = this.$(".post-admin-menu");
    $postAdminMenu.show();
    $("html").on("mouseup.post-admin-menu", function() {
      $postAdminMenu.hide();
      $("html").off("mouseup.post-admin-menu");
    });
  },

  clickToggleWiki() {
    this.sendAction('toggleWiki', this.get('post'));
  },

  clickTogglePostType() {
    this.sendAction("togglePostType", this.get("post"));
  },

  clickRebakePost() {
    this.sendAction("rebakePost", this.get("post"));
  },

  clickUnhidePost() {
    this.sendAction("unhidePost", this.get("post"));
  },

  buttonForShowMoreActions() {
    return new Button('showMoreActions', 'show_more', 'ellipsis-h');
  },

  clickShowMoreActions() {
    this.set('collapsed', false);
  }

});

PostMenuComponent.reopenClass({
  registerButton(callback){
    this._registerButtonCallbacks = this._registerButtonCallbacks || [];
    this._registerButtonCallbacks.push(callback);
  }
});

export default PostMenuComponent;
