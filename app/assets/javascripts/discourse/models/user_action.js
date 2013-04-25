/**
  A data model representing actions users have taken

  @class UserAction
  @extends Discourse.Model
  @namespace Discourse
  @module Discourse
**/
Discourse.UserAction = Discourse.Model.extend({

  descriptionHtml: (function() {
    var action = this.get('action_type');
    var ua = Discourse.UserAction;
    var actions = [ua.LIKE, ua.WAS_LIKED, ua.STAR, ua.EDIT, ua.BOOKMARK, ua.GOT_PRIVATE_MESSAGE, ua.NEW_PRIVATE_MESSAGE];
    var icon = "";
    var sentence = "";
    var sameUser = (this.get('username') === Discourse.get('currentUser.username'));

    if (action === null || actions.indexOf(action) >= 0) {
      if (this.get('isPM')) {
        icon = '<i class="icon icon-envelope-alt" title="{{i18n user.stream.private_message}}"></i>';
        if (sameUser) {
          sentence = Em.String.i18n('user_action.sent_by_you', { userUrl: this.get('userUrl') });
        } else {
          sentence = Em.String.i18n('user_action.sent_by_user', { user: this.get('name'), userUrl: this.get('userUrl') });
        }
      } else {
        if (sameUser) {
          sentence = Em.String.i18n('user_action.posted_by_you', { userUrl: this.get('userUrl') });
        } else {
          sentence = Em.String.i18n('user_action.posted_by_user', { user: this.get('name'), userUrl: this.get('userUrl') });
        }
      }
    } else if (action === ua.NEW_TOPIC) {
      if (sameUser) {
        sentence = Em.String.i18n('user_action.you_posted_topic', { userUrl: this.get('userUrl'), topicUrl: this.get('replyUrl') });
      } else {
        sentence = Em.String.i18n('user_action.user_posted_topic', { user: this.get('name'), userUrl: this.get('userUrl'), topicUrl: this.get('replyUrl') });
      }
    } else if (action === ua.POST || action === ua.RESPONSE) {
      if (this.get('reply_to_post_number')) {
        if (sameUser) {
          sentence = Em.String.i18n('user_action.you_replied_to_post', { post_number: '#' + this.get('reply_to_post_number'),
              userUrl: this.get('userUrl'), postUrl: this.get('postUrl') });
        } else {
          sentence = Em.String.i18n('user_action.user_replied_to_post', { user: this.get('name'),
              post_number: '#' + this.get('reply_to_post_number'), userUrl: this.get('userUrl'), postUrl: this.get('postUrl') });
        }
      } else {
        if (sameUser) {
          sentence = Em.String.i18n('user_action.you_replied_to_topic', { userUrl: this.get('userUrl'),
              topicUrl: this.get('replyUrl') });
        } else {
          sentence = Em.String.i18n('user_action.user_replied_to_topic', { user: this.get('name'),
              userUrl: this.get('userUrl'), topicUrl: this.get('replyUrl') });
        }
      }
    } else if (action === ua.MENTION) {
      if (sameUser) {
        sentence = Em.String.i18n('user_action.you_mentioned_user', { user: this.get('target_name'),
            user1Url: this.get('userUrl'), user2Url: this.get('targetUserUrl') });
      } else {
        if (this.get('target_username') === Discourse.get('currentUser.username')) {
          sentence = Em.String.i18n('user_action.user_mentioned_you', { user: this.get('name'),
              user1Url: this.get('userUrl'), user2Url: this.get('targetUserUrl') });
        } else {
          sentence = Em.String.i18n('user_action.user_mentioned_user', { user: this.get('name'),
              another_user: this.get('target_name'), user1Url: this.get('userUrl'), user2Url: this.get('targetUserUrl') });
        }
      }
    } else {
      Ember.debug("Invalid user action: " + action);
    }

    return new Handlebars.SafeString(icon + " " + sentence);
  }).property(),

  targetUserUrl: (function() {
    return Discourse.Utilities.userUrl(this.get('target_username'));
  }).property(),

  userUrl: (function() {
    return Discourse.Utilities.userUrl(this.get('username'));
  }).property(),

  postUrl: (function() {
    return Discourse.Utilities.postUrl(this.get('slug'), this.get('topic_id'), this.get('post_number'));
  }).property(),

  replyUrl: (function() {
    return Discourse.Utilities.postUrl(this.get('slug'), this.get('topic_id'), this.get('reply_to_post_number'));
  }).property(),

  isPM: (function() {
    var a = this.get('action_type');
    return a === Discourse.UserAction.NEW_PRIVATE_MESSAGE || a === Discourse.UserAction.GOT_PRIVATE_MESSAGE;
  }).property(),

  isPostAction: (function() {
    var a;
    a = this.get('action_type');
    return a === Discourse.UserAction.RESPONSE || a === Discourse.UserAction.POST || a === Discourse.UserAction.NEW_TOPIC;
  }).property(),

  addChild: function(action) {
    var bucket, current, groups, ua;
    groups = this.get("childGroups");
    if (!groups) {
      groups = {
        likes: Discourse.UserActionGroup.create({
          icon: "icon-heart"
        }),
        stars: Discourse.UserActionGroup.create({
          icon: "icon-star"
        }),
        edits: Discourse.UserActionGroup.create({
          icon: "icon-pencil"
        }),
        bookmarks: Discourse.UserActionGroup.create({
          icon: "icon-bookmark"
        })
      };
    }
    this.set("childGroups", groups);
    ua = Discourse.UserAction;
    bucket = (function() {
      switch (action.action_type) {
        case ua.LIKE:
        case ua.WAS_LIKED:
          return "likes";
        case ua.STAR:
          return "stars";
        case ua.EDIT:
          return "edits";
        case ua.BOOKMARK:
          return "bookmarks";
      }
    })();
    current = groups[bucket];
    if (current) {
      current.push(action);
    }
  },

  children: (function() {
    var g, rval;
    g = this.get("childGroups");
    rval = [];
    if (g) {
      rval = [g.likes, g.stars, g.edits, g.bookmarks].filter(function(i) {
        return i.get("items") && i.get("items").length > 0;
      });
    }
    return rval;
  }).property("childGroups"),

  switchToActing: function() {
    this.set('username', this.get('acting_username'));
    this.set('avatar_template', this.get('acting_avatar_template'));
    this.set('name', this.get('acting_name'));
  }
});

Discourse.UserAction.reopenClass({
  collapseStream: function(stream) {
    var collapse, collapsed, pos, uniq;
    collapse = [this.LIKE, this.WAS_LIKED, this.STAR, this.EDIT, this.BOOKMARK];
    uniq = {};
    collapsed = Em.A();
    pos = 0;
    stream.each(function(item) {
      var current, found, key;
      key = "" + item.topic_id + "-" + item.post_number;
      found = uniq[key];
      if (found === void 0) {
        if (collapse.indexOf(item.action_type) >= 0) {
          current = Discourse.UserAction.create(item);
          current.set('action_type', null);
          current.set('description', null);
          item.switchToActing();
          current.addChild(item);
        } else {
          current = item;
        }
        uniq[key] = pos;
        collapsed[pos] = current;
        pos += 1;
      } else {
        if (collapse.indexOf(item.action_type) >= 0) {
          item.switchToActing();
          return collapsed[found].addChild(item);
        } else {
          collapsed[found].set('action_type', item.get('action_type'));
          return collapsed[found].set('description', item.get('description'));
        }
      }
    });
    return collapsed;
  },

  // in future we should be sending this through from the server
  LIKE: 1,
  WAS_LIKED: 2,
  BOOKMARK: 3,
  NEW_TOPIC: 4,
  POST: 5,
  RESPONSE: 6,
  MENTION: 7,
  QUOTE: 9,
  STAR: 10,
  EDIT: 11,
  NEW_PRIVATE_MESSAGE: 12,
  GOT_PRIVATE_MESSAGE: 13
});

Discourse.UserAction.reopenClass({
  statGroups: (function() {
    var g;
    g = {};
    g[Discourse.UserAction.RESPONSE] = [Discourse.UserAction.RESPONSE, Discourse.UserAction.MENTION, Discourse.UserAction.QUOTE];
    return g;
  })()
});


