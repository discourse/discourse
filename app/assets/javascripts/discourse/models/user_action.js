/**
  A data model representing actions users have taken

  @class UserAction
  @extends Discourse.Model
  @namespace Discourse
  @module Discourse
**/

var UserActionTypes = {
      likes_given: 1,
      likes_received: 2,
      bookmarks: 3,
      topics: 4,
      posts: 5,
      replies: 6,
      mentions: 7,
      quotes: 9,
      starred: 10,
      edits: 11,
      messages_sent: 12,
      messages_received: 13
    },
    InvertedActionTypes = {};

_.each(UserActionTypes, function (k, v) {
  InvertedActionTypes[k] = v;
});

Discourse.UserAction = Discourse.Model.extend({

  _attachCategory: function() {
    var categoryId = this.get('category_id');
    if (categoryId) {
      this.set('category', Discourse.Category.findById(categoryId));
    }
  }.on('init'),

  /**
    Return an i18n key we will use for the description text of a user action.

    @property descriptionKey
  **/
  descriptionKey: function() {
    var action = this.get('action_type');
    if (action === null || Discourse.UserAction.TO_SHOW.indexOf(action) >= 0) {
      if (this.get('isPM')) {
        return this.get('sameUser') ? 'sent_by_you' : 'sent_by_user';
      } else {
        return this.get('sameUser') ? 'posted_by_you' : 'posted_by_user';
      }
    }

    if (this.get('topicType')) {
      return this.get('sameUser') ? 'you_posted_topic' : 'user_posted_topic';
    }

    if (this.get('postReplyType')) {
      if (this.get('reply_to_post_number')) {
        return this.get('sameUser') ? 'you_replied_to_post' : 'user_replied_to_post';
      } else {
        return this.get('sameUser') ? 'you_replied_to_topic' : 'user_replied_to_topic';
      }
    }

    if (this.get('mentionType')) {
      if (this.get('sameUser')) {
        return 'you_mentioned_user';
      } else {
        return this.get('targetUser') ? 'user_mentioned_you' : 'user_mentioned_user';
      }
    }
  }.property('action_type'),

  sameUser: function() {
    return this.get('username') === Discourse.User.currentProp('username');
  }.property('username'),

  targetUser: function() {
    return this.get('target_username') === Discourse.User.currentProp('username');
  }.property('target_username'),

  presentName: Em.computed.any('name', 'username'),
  targetDisplayName: Em.computed.any('target_name', 'target_username'),
  actingDisplayName: Em.computed.any('acting_name', 'acting_username'),
  targetUserUrl: Discourse.computed.url('target_username', '/users/%@'),

  usernameLower: function() {
    return this.get('username').toLowerCase();
  }.property('username'),

  userUrl: Discourse.computed.url('usernameLower', '/users/%@'),

  postUrl: function() {
    return Discourse.Utilities.postUrl(this.get('slug'), this.get('topic_id'), this.get('post_number'));
  }.property(),

  replyUrl: function() {
    return Discourse.Utilities.postUrl(this.get('slug'), this.get('topic_id'), this.get('reply_to_post_number'));
  }.property(),

  replyType: Em.computed.equal('action_type', UserActionTypes.replies),
  postType: Em.computed.equal('action_type', UserActionTypes.posts),
  topicType: Em.computed.equal('action_type', UserActionTypes.topics),
  bookmarkType: Em.computed.equal('action_type', UserActionTypes.bookmarks),
  messageSentType: Em.computed.equal('action_type', UserActionTypes.messages_sent),
  messageReceivedType: Em.computed.equal('action_type', UserActionTypes.messages_received),
  mentionType: Em.computed.equal('action_type', UserActionTypes.mentions),
  isPM: Em.computed.or('messageSentType', 'messageReceivedType'),
  postReplyType: Em.computed.or('postType', 'replyType'),
  removableBookmark: Em.computed.and('bookmarkType', 'sameUser'),

  addChild: function(action) {
    var groups = this.get("childGroups");
    if (!groups) {
      groups = {
        likes: Discourse.UserActionGroup.create({ icon: "fa fa-heart" }),
        stars: Discourse.UserActionGroup.create({ icon: "fa fa-star" }),
        edits: Discourse.UserActionGroup.create({ icon: "fa fa-pencil" }),
        bookmarks: Discourse.UserActionGroup.create({ icon: "fa fa-bookmark" })
      };
    }
    this.set("childGroups", groups);

    var bucket = (function() {
      switch (action.action_type) {
        case UserActionTypes.likes_given:
        case UserActionTypes.likes_received:
          return "likes";
        case UserActionTypes.starred:
          return "stars";
        case UserActionTypes.edits:
          return "edits";
        case UserActionTypes.bookmarks:
          return "bookmarks";
      }
    })();
    var current = groups[bucket];
    if (current) {
      current.push(action);
    }
  },

  children: function() {
    var g = this.get("childGroups");
    var rval = [];
    if (g) {
      rval = [g.likes, g.stars, g.edits, g.bookmarks].filter(function(i) {
        return i.get("items") && i.get("items").length > 0;
      });
    }
    return rval;
  }.property("childGroups",
    "childGroups.likes.items", "childGroups.likes.items.@each",
    "childGroups.stars.items", "childGroups.stars.items.@each",
    "childGroups.edits.items", "childGroups.edits.items.@each",
    "childGroups.bookmarks.items", "childGroups.bookmarks.items.@each"),

  switchToActing: function() {
    this.setProperties({
      username: this.get('acting_username'),
      uploaded_avatar_id: this.get('acting_uploaded_avatar_id'),
      name: this.get('actingDisplayName')
    });
  }
});

Discourse.UserAction.reopenClass({
  collapseStream: function(stream) {
    var uniq = {},
        collapsed = [],
        pos = 0;

    stream.forEach(function(item) {
      var key = "" + item.topic_id + "-" + item.post_number;
      var found = uniq[key];
      if (found === void 0) {

        var current;
        if (Discourse.UserAction.TO_COLLAPSE.indexOf(item.action_type) >= 0) {
          current = Discourse.UserAction.create(item);
          item.switchToActing();
          current.addChild(item);
        } else {
          current = item;
        }
        uniq[key] = pos;
        collapsed[pos] = current;
        pos += 1;
      } else {
        if (Discourse.UserAction.TO_COLLAPSE.indexOf(item.action_type) >= 0) {
          item.switchToActing();
          collapsed[found].addChild(item);
        } else {
          collapsed[found].setProperties(item.getProperties('action_type', 'description'));
        }
      }
    });
    return collapsed;
  },

  TYPES: UserActionTypes,
  TYPES_INVERTED: InvertedActionTypes,

  TO_COLLAPSE: [
    UserActionTypes.likes_given,
    UserActionTypes.likes_received,
    UserActionTypes.starred,
    UserActionTypes.edits,
    UserActionTypes.bookmarks
  ],

  TO_SHOW: [
    UserActionTypes.likes_given,
    UserActionTypes.likes_received,
    UserActionTypes.starred,
    UserActionTypes.edits,
    UserActionTypes.bookmarks,
    UserActionTypes.messages_sent,
    UserActionTypes.messages_received
  ]

});
