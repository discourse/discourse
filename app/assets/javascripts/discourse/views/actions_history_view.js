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
      var actionString, iconsHtml;
      buffer.push("<div class='post-action'>");

      // TODO multi line expansion for flags
      var postUrl;
      if (c.get('users')) {
        iconsHtml = "";
        c.get('users').forEach(function(u) {
          iconsHtml += "<a href=\"" + Discourse.getURL("/users/") + (u.get('username_lower')) + "\">";
          if (u.post_url) {
            postUrl = postUrl || u.post_url;
          }
          iconsHtml += Discourse.Utilities.avatarImg({
            size: 'small',
            username: u.get('username'),
            avatarTemplate: u.get('avatar_template'),
            title: u.get('username')
          });
          iconsHtml += "</a>";
        });

        var key = 'post.actions.people.' + c.get('actionType.name_key');
        if(postUrl) {
          key = key + "_with_url";
        }
        buffer.push(" " + Em.String.i18n(key, { icons: iconsHtml, postUrl: postUrl}) + ".");
      } else {
        buffer.push("<a href='#' data-who-acted='" + (c.get('id')) + "'>" + (c.get('description')) + "</a>.");
      }

      if (c.get('can_act') && !c.get('actionType.is_custom_flag')) {
        actionString = Em.String.i18n("post.actions.it_too." + c.get('actionType.name_key'));
        buffer.push(" <a href='#' data-act='" + (c.get('id')) + "'>" + actionString + "</a>.");
      }

      if (c.get('can_undo')) {
        actionString = Em.String.i18n("post.actions.undo." + c.get('actionType.name_key') );
        buffer.push(" <a href='#' data-undo='" + (c.get('id')) + "'>" + actionString + "</a>.");
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


