import RestModel from 'discourse/models/rest';
import { url } from 'discourse/lib/computed';
import { on } from 'ember-addons/ember-computed-decorators';
import computed from 'ember-addons/ember-computed-decorators';
import UserActionGroup from 'discourse/models/user-action-group';

const UserActionTypes = {
  likes_given: 1,
  likes_received: 2,
  bookmarks: 3,
  topics: 4,
  posts: 5,
  replies: 6,
  mentions: 7,
  quotes: 9,
  edits: 11,
  messages_sent: 12,
  messages_received: 13,
  pending: 14
};
const InvertedActionTypes = {};

_.each(UserActionTypes, (k, v) => {
  InvertedActionTypes[k] = v;
});

const UserAction = RestModel.extend({

  @on("init")
  _attachCategory() {
    const categoryId = this.get('category_id');
    if (categoryId) {
      this.set('category', Discourse.Category.findById(categoryId));
    }
  },

  @computed("action_type")
  descriptionKey(action) {
    if (action === null || UserAction.TO_SHOW.indexOf(action) >= 0) {
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
  },

  @computed("username")
  sameUser(username) {
    return username === Discourse.User.currentProp('username');
  },

  @computed("target_username")
  targetUser(targetUsername) {
    return targetUsername === Discourse.User.currentProp('username');
  },

  presentName: Em.computed.any('name', 'username'),
  targetDisplayName: Em.computed.any('target_name', 'target_username'),
  actingDisplayName: Em.computed.any('acting_name', 'acting_username'),
  targetUserUrl: url('target_username', '/users/%@'),

  @computed("username")
  usernameLower(username) {
    return username.toLowerCase();
  },

  userUrl: url('usernameLower', '/users/%@'),

  @computed()
  postUrl() {
    return Discourse.Utilities.postUrl(this.get('slug'), this.get('topic_id'), this.get('post_number'));
  },

  @computed()
  replyUrl() {
    return Discourse.Utilities.postUrl(this.get('slug'), this.get('topic_id'), this.get('reply_to_post_number'));
  },

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

  addChild(action) {
    let groups = this.get("childGroups");
    if (!groups) {
      groups = {
        likes: UserActionGroup.create({ icon: "fa fa-heart" }),
        stars: UserActionGroup.create({ icon: "fa fa-star" }),
        edits: UserActionGroup.create({ icon: "fa fa-pencil" }),
        bookmarks: UserActionGroup.create({ icon: "fa fa-bookmark" })
      };
    }
    this.set("childGroups", groups);

    const bucket = (function() {
      switch (action.action_type) {
        case UserActionTypes.likes_given:
        case UserActionTypes.likes_received:
          return "likes";
        case UserActionTypes.edits:
          return "edits";
        case UserActionTypes.bookmarks:
          return "bookmarks";
      }
    })();
    const current = groups[bucket];
    if (current) {
      current.push(action);
    }
  },

  children: function() {
    const g = this.get("childGroups");
    let rval = [];
    if (g) {
      rval = [g.likes, g.stars, g.edits, g.bookmarks].filter(function(i) {
        return i.get("items") && i.get("items").length > 0;
      });
    }
    return rval;
  }.property("childGroups",
    "childGroups.likes.items", "childGroups.likes.items.[]",
    "childGroups.stars.items", "childGroups.stars.items.[]",
    "childGroups.edits.items", "childGroups.edits.items.[]",
    "childGroups.bookmarks.items", "childGroups.bookmarks.items.[]"),

  switchToActing() {
    this.setProperties({
      username: this.get('acting_username'),
      name: this.get('actingDisplayName')
    });
  }
});

UserAction.reopenClass({
  collapseStream(stream) {
    const uniq = {};
    const collapsed = [];
    let pos = 0;

    stream.forEach(item => {
      const key = "" + item.topic_id + "-" + item.post_number;
      const found = uniq[key];
      if (found === void 0) {

        let current;
        if (UserAction.TO_COLLAPSE.indexOf(item.action_type) >= 0) {
          current = UserAction.create(item);
          item.switchToActing();
          current.addChild(item);
        } else {
          current = item;
        }
        uniq[key] = pos;
        collapsed[pos] = current;
        pos += 1;
      } else {
        if (UserAction.TO_COLLAPSE.indexOf(item.action_type) >= 0) {
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
    UserActionTypes.edits,
    UserActionTypes.bookmarks
  ],

  TO_SHOW: [
    UserActionTypes.likes_given,
    UserActionTypes.likes_received,
    UserActionTypes.edits,
    UserActionTypes.bookmarks,
    UserActionTypes.messages_sent,
    UserActionTypes.messages_received
  ]

});

export default UserAction;
