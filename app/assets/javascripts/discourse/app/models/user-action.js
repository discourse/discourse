import { and, equal, or } from "@ember/object/computed";
import discourseComputed from "discourse-common/utils/decorators";
import categoryFromId from "discourse-common/utils/category-macro";
import RestModel from "discourse/models/rest";
import User from "discourse/models/user";
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
};
const InvertedActionTypes = {};

Object.keys(UserActionTypes).forEach(
  (k) => (InvertedActionTypes[k] = UserActionTypes[k])
);

const UserAction = RestModel.extend({
  category: categoryFromId("category_id"),

  @discourseComputed("action_type")
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

  @discourseComputed("username")
  sameUser(username) {
    return username === User.currentProp("username");
  },

  @discourseComputed("target_username")
  targetUser(targetUsername) {
    return targetUsername === User.currentProp("username");
  },

  presentName: or("name", "username"),
  targetDisplayName: or("target_name", "target_username"),
  actingDisplayName: or("acting_name", "acting_username"),

  @discourseComputed("target_username")
  targetUserUrl(username) {
    return userPath(username);
  },

  @discourseComputed("username")
  usernameLower(username) {
    return username.toLowerCase();
  },

  @discourseComputed("usernameLower")
  userUrl(usernameLower) {
    return userPath(usernameLower);
  },

  @discourseComputed()
  postUrl() {
    return postUrl(this.slug, this.topic_id, this.post_number);
  },

  @discourseComputed()
  replyUrl() {
    return postUrl(this.slug, this.topic_id, this.reply_to_post_number);
  },

  replyType: equal("action_type", UserActionTypes.replies),
  postType: equal("action_type", UserActionTypes.posts),
  topicType: equal("action_type", UserActionTypes.topics),
  bookmarkType: equal("action_type", UserActionTypes.bookmarks),
  messageSentType: equal("action_type", UserActionTypes.messages_sent),
  messageReceivedType: equal("action_type", UserActionTypes.messages_received),
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
        bookmarks: UserActionGroup.create({ icon: "bookmark" }),
      };
    }
    this.set("childGroups", groups);

    const bucket = (function () {
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

  @discourseComputed(
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
      rval = [g.likes, g.stars, g.edits, g.bookmarks].filter(function (i) {
        return i.get("items") && i.get("items").length > 0;
      });
    }
    return rval;
  },

  switchToActing() {
    this.setProperties({
      username: this.acting_username,
      name: this.actingDisplayName,
    });
  },
});

UserAction.reopenClass({
  collapseStream(stream) {
    const uniq = {};
    const collapsed = [];
    let pos = 0;

    stream.forEach((item) => {
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
    UserActionTypes.bookmarks,
  ],

  TO_SHOW: [
    UserActionTypes.likes_given,
    UserActionTypes.likes_received,
    UserActionTypes.edits,
    UserActionTypes.bookmarks,
    UserActionTypes.messages_sent,
    UserActionTypes.messages_received,
  ],
});

export default UserAction;
