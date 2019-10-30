import { or, equal, and } from "@ember/object/computed";
import RestModel from "discourse/models/rest";
import { on } from "ember-addons/ember-computed-decorators";
import computed from "ember-addons/ember-computed-decorators";
import UserActionGroup from "discourse/models/user-action-group";
import { postUrl } from "discourse/lib/utilities";
import { userPath } from "discourse/lib/url";

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

Object.keys(UserActionTypes).forEach(
  k => (InvertedActionTypes[k] = UserActionTypes[k])
);

const UserAction = RestModel.extend({
  @on("init")
  _attachCategory() {
    const categoryId = this.category_id;
    if (categoryId) {
      this.set("category", Discourse.Category.findById(categoryId));
    }
  },

  @computed("action_type")
  descriptionKey(action) {
    if (action === null || UserAction.TO_SHOW.indexOf(action) >= 0) {
      if (this.isPM) {
        return this.sameUser ? "sent_by_you" : "sent_by_user";
      } else {
        return this.sameUser ? "posted_by_you" : "posted_by_user";
      }
    }

    if (this.topicType) {
      return this.sameUser ? "you_posted_topic" : "user_posted_topic";
    }

    if (this.postReplyType) {
      if (this.reply_to_post_number) {
        return this.sameUser ? "you_replied_to_post" : "user_replied_to_post";
      } else {
        return this.sameUser ? "you_replied_to_topic" : "user_replied_to_topic";
      }
    }

    if (this.mentionType) {
      if (this.sameUser) {
        return "you_mentioned_user";
      } else {
        return this.targetUser ? "user_mentioned_you" : "user_mentioned_user";
      }
    }
  },

  @computed("username")
  sameUser(username) {
    return username === Discourse.User.currentProp("username");
  },

  @computed("target_username")
  targetUser(targetUsername) {
    return targetUsername === Discourse.User.currentProp("username");
  },

  presentName: or("name", "username"),
  targetDisplayName: or("target_name", "target_username"),
  actingDisplayName: or("acting_name", "acting_username"),

  @computed("target_username")
  targetUserUrl(username) {
    return userPath(username);
  },

  @computed("username")
  usernameLower(username) {
    return username.toLowerCase();
  },

  @computed("usernameLower")
  userUrl(usernameLower) {
    return userPath(usernameLower);
  },

  @computed()
  postUrl() {
    return postUrl(this.slug, this.topic_id, this.post_number);
  },

  @computed()
  replyUrl() {
    return postUrl(this.slug, this.topic_id, this.reply_to_post_number);
  },

  replyType: equal("action_type", UserActionTypes.replies),
  postType: equal("action_type", UserActionTypes.posts),
  topicType: equal("action_type", UserActionTypes.topics),
  bookmarkType: equal("action_type", UserActionTypes.bookmarks),
  messageSentType: equal(
    "action_type",
    UserActionTypes.messages_sent
  ),
  messageReceivedType: equal(
    "action_type",
    UserActionTypes.messages_received
  ),
  mentionType: equal("action_type", UserActionTypes.mentions),
  isPM: or("messageSentType", "messageReceivedType"),
  postReplyType: or("postType", "replyType"),
  removableBookmark: and("bookmarkType", "sameUser"),

  addChild(action) {
    let groups = this.childGroups;
    if (!groups) {
      groups = {
        likes: UserActionGroup.create({ icon: "heart" }),
        stars: UserActionGroup.create({ icon: "star" }),
        edits: UserActionGroup.create({ icon: "pencil-alt" }),
        bookmarks: UserActionGroup.create({ icon: "bookmark" })
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

  @computed(
    "childGroups",
    "childGroups.likes.items",
    "childGroups.likes.items.[]",
    "childGroups.stars.items",
    "childGroups.stars.items.[]",
    "childGroups.edits.items",
    "childGroups.edits.items.[]",
    "childGroups.bookmarks.items",
    "childGroups.bookmarks.items.[]"
  )
  children() {
    const g = this.childGroups;
    let rval = [];
    if (g) {
      rval = [g.likes, g.stars, g.edits, g.bookmarks].filter(function(i) {
        return i.get("items") && i.get("items").length > 0;
      });
    }
    return rval;
  },

  switchToActing() {
    this.setProperties({
      username: this.acting_username,
      name: this.actingDisplayName
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
          collapsed[found].setProperties(
            item.getProperties("action_type", "description")
          );
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
