/**
  This view renders a menu below a post. It uses buffered rendering for performance.

  @class PostMenuView
  @extends Discourse.View
  @namespace Discourse
  @module Discourse
**/
Discourse.PostMenuView = Discourse.View.extend({
  tagName: 'section',
  classNames: ['post-menu-area', 'clearfix'],

  render: function(buffer) {
    var post = this.get('post');
    this.renderReplies(post, buffer);
    buffer.push("<nav class='post-controls'>");

    var postMenuView = this;
    Discourse.get('postButtons').forEach(function(button) {
      var renderer = "render" + button;
      if(postMenuView[renderer]) postMenuView[renderer](post, buffer);
    });
    buffer.push("</nav>");
  },

  // Delegate click actions
  click: function(e) {
    var $target = $(e.target);
    var action = $target.data('action') || $target.parent().data('action');
    if (!action) return;

    var handler = this["click" + action.capitalize()];
    if (!handler) return;

    handler.call(this);
  },

  // Trigger re-rendering
  needsToRender: function() {
    this.rerender();
  }.observes('post.deleted_at', 'post.flagsAvailable.@each', 'post.url', 'post.bookmarked', 'post.reply_count', 'post.showRepliesBelow', 'post.can_delete'),

  // Replies Button
  renderReplies: function(post, buffer) {
    if (!post.get('showRepliesBelow')) return;

    var reply_count = post.get('reply_count');
    buffer.push("<button class='show-replies' data-action='replies'>");
    buffer.push("<span class='badge-posts'>" + reply_count + "</span>");
    buffer.push(Em.String.i18n("post.has_replies", { count: reply_count }));

    var icon = this.get('postView.repliesShown') ? 'icon-chevron-up' : 'icon-chevron-down';
    return buffer.push("<i class='icon " + icon + "'></i></button>");
  },

  clickReplies: function() {
    this.get('postView').showReplies();
  },

  // Delete button
  renderDelete: function(post, buffer) {
    if (post.get('post_number') === 1 && this.get('controller.content.can_delete')) {
      buffer.push("<button title=\"" +
                  (Em.String.i18n("topic.actions.delete")) +
                  "\" data-action=\"deleteTopic\"><i class=\"icon-trash\"></i></button>");
      return;
    }
    // Show the correct button (undo or delete)
    if (post.get('deleted_at')) {
      if (post.get('can_recover')) {
        buffer.push("<button title=\"" +
                    (Em.String.i18n("post.controls.undelete")) +
                    "\" data-action=\"recover\" class=\"delete\"><i class=\"icon-undo\"></i></button>");
      }
    } else if (post.get('can_delete')) {
      buffer.push("<button title=\"" +
                 (Em.String.i18n("post.controls.delete")) +
                 "\" data-action=\"delete\" class=\"delete\"><i class=\"icon-trash\"></i></button>");
    }
  },

  clickDeleteTopic: function() {
    this.get('controller').deleteTopic();
  },

  clickRecover: function() {
    this.get('controller').recoverPost(this.get('post'));
  },

  clickDelete: function() {
    this.get('controller').deletePost(this.get('post'));
  },

  // Like button
  renderLike: function(post, buffer) {
    if (!post.get('actionByName.like.can_act')) return;
    buffer.push("<button title=\"" +
                (Em.String.i18n("post.controls.like")) +
                "\" data-action=\"like\" class='like'><i class=\"icon-heart\"></i></button>");
  },

  clickLike: function() {
    var likeAction = this.get('post.actionByName.like');
    if (likeAction) likeAction.act();
  },

  // Flag button
  renderFlag: function(post, buffer) {
    if (!this.present('post.flagsAvailable')) return;
    buffer.push("<button title=\"" +
                (Em.String.i18n("post.controls.flag")) +
                "\" data-action=\"flag\"><i class=\"icon-flag\"></i></button>");
  },

  clickFlag: function() {
    this.get('controller').showFlags(this.get('post'));
  },

  // Edit button
  renderEdit: function(post, buffer) {
    if (!post.get('can_edit')) return;
    buffer.push("<button title=\"" +
                 (Em.String.i18n("post.controls.edit")) +
                 "\" data-action=\"edit\"><i class=\"icon-pencil\"></i></button>");
  },

  clickEdit: function() {
    this.get('controller').editPost(this.get('post'));
  },

  // Share button
  renderShare: function(post, buffer) {
    buffer.push("<button title=\"" +
                 (Em.String.i18n("post.controls.share")) +
                 "\" data-share-url=\"" + (post.get('shareUrl')) + "\"><i class=\"icon-link\"></i></button>");
  },

  // Reply button
  renderReply: function(post, buffer) {
    if (!this.get('controller.content.can_create_post')) return;
    buffer.push("<button title=\"" +
                 (Em.String.i18n("post.controls.reply")) +
                 "\" class='create' data-action=\"reply\"><i class='icon-reply'></i>" +
                 (Em.String.i18n("topic.reply.title")) + "</button>");
  },

  clickReply: function() {
    this.get('controller').replyToPost(this.get('post'));
  },

  // Bookmark button
  renderBookmark: function(post, buffer) {
    if (!Discourse.get('currentUser')) return;

    var icon = 'bookmark';
    if (!this.get('post.bookmarked')) {
      icon += '-empty';
    }
    buffer.push("<button title=\"" +
                (Em.String.i18n("post.controls.bookmark")) +
                "\" data-action=\"bookmark\"><i class=\"icon-" + icon + "\"></i></button>");
  },

  clickBookmark: function() {
    this.get('post').toggleProperty('bookmarked');
  }

});
