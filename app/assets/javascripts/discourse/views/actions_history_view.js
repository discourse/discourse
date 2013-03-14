/**
  This view handles rendering of what actions have been taken on a post. It uses
  buffer rendering for performance rather than a template.

  @class ActionsHistoryView
  @extends Discourse.View
  @namespace Discourse
  @module Discourse
**/
Discourse.ActionsHistoryView = Discourse.View.extend({
  tagName: 'section',
  classNameBindings: [':post-actions', 'hidden'],

  hidden: (function() {
    return this.blank('content');
  }).property('content.@each'),

  usersChanged: (function() {
    return this.rerender();
  }).observes('content.@each', 'content.users.@each'),

  // This was creating way too many bound ifs and subviews in the handlebars version.
  render: function(buffer) {

    if (!this.present('content')) return;
    return this.get('content').forEach(function(c) {
      var alsoName;
      buffer.push("<div class='post-action'>");

      if (c.get('users')) {
        c.get('users').forEach(function(u) {
          buffer.push("<a href=\"" + Discourse.getURL("/users/") + (u.get('username_lower')) + "\">");
          buffer.push(Discourse.Utilities.avatarImg({
            size: 'small',
            username: u.get('username'),
            avatarTemplate: u.get('avatar_template')
          }));
          return buffer.push("</a>");
        });
        buffer.push(" " + (c.get('actionType.long_form')) + ".");
      } else {
        buffer.push("<a href='#' data-who-acted='" + (c.get('id')) + "'>" + (c.get('description')) + "</a>.");
      }

      if (c.get('can_act')) {
        alsoName = Em.String.i18n("post.actions.it_too", { alsoName: c.get('actionType.alsoName') });
        buffer.push(" <a href='#' data-act='" + (c.get('id')) + "'>" + alsoName + "</a>.");
      }

      if (c.get('can_undo')) {
        alsoName = Em.String.i18n("post.actions.undo", { alsoName: c.get('actionType.alsoNameLower') });
        buffer.push(" <a href='#' data-undo='" + (c.get('id')) + "'>" + alsoName + "</a>.");
      }

      if (c.get('can_clear_flags')) {
        buffer.push(" <a href='#' data-clear-flags='" + (c.get('id')) + "'>" + (Em.String.i18n("post.actions.clear_flags", { count: c.count })) + "</a>.");
      }

      buffer.push("</div>");
    });
  },

  click: function(e) {
    var $target, actionTypeId;
    $target = $(e.target);

    if (actionTypeId = $target.data('clear-flags')) {
      this.get('controller').clearFlags(this.content.findProperty('id', actionTypeId));
      return false;
    }

    // User wants to know who actioned it
    if (actionTypeId = $target.data('who-acted')) {
      this.get('controller').whoActed(this.content.findProperty('id', actionTypeId));
      return false;
    }

    if (actionTypeId = $target.data('act')) {
      this.content.findProperty('id', actionTypeId).act();
      return false;
    }

    if (actionTypeId = $target.data('undo')) {
      this.content.findProperty('id', actionTypeId).undo();
      return false;
    }

    return false;
  }
});


