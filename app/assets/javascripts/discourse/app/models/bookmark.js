import Category from "discourse/models/category";
import I18n from "I18n";
import { Promise } from "rsvp";
import RestModel from "discourse/models/rest";
import User from "discourse/models/user";
import Topic from "discourse/models/topic";
import { ajax } from "discourse/lib/ajax";
import { computed } from "@ember/object";
import discourseComputed from "discourse-common/utils/decorators";
import { formattedReminderTime } from "discourse/lib/bookmark";
import getURL from "discourse-common/lib/get-url";
import { longDate } from "discourse/lib/formatter";
import { none } from "@ember/object/computed";

export const AUTO_DELETE_PREFERENCES = {
  NEVER: 0,
  WHEN_REMINDER_SENT: 1,
  ON_OWNER_REPLY: 2,
};

const Bookmark = RestModel.extend({
  newBookmark: none("id"),

  @computed
  get url() {
    return getURL(`/bookmarks/${this.id}`);
  },

  destroy() {
    if (this.newBookmark) {
      return Promise.resolve();
    }

    return ajax(this.url, {
      type: "DELETE",
    });
  },

  togglePin() {
    if (this.newBookmark) {
      return Promise.resolve();
    }

    return ajax(this.url + "/toggle_pin", {
      type: "PUT",
    });
  },

  pinAction() {
    return this.pinned ? "unpin" : "pin";
  },

  @discourseComputed("highest_post_number", "url")
  lastPostUrl(highestPostNumber) {
    return this.urlForPostNumber(highestPostNumber);
  },

  // Helper to build a Url with a post number
  urlForPostNumber(postNumber) {
    let url = getURL(`/t/${this.topic_id}`);
    if (postNumber > 0) {
      url += `/${postNumber}`;
    }
    return url;
  },

  // returns createdAt if there's no bumped date
  @discourseComputed("bumped_at", "createdAt")
  bumpedAt(bumped_at, createdAt) {
    if (bumped_at) {
      return new Date(bumped_at);
    } else {
      return createdAt;
    }
  },

  @discourseComputed("bumpedAt", "createdAt")
  bumpedAtTitle(bumpedAt, createdAt) {
    const firstPost = I18n.t("first_post");
    const lastPost = I18n.t("last_post");
    const createdAtDate = longDate(createdAt);
    const bumpedAtDate = longDate(bumpedAt);

    return I18n.messageFormat("topic.bumped_at_title_MF", {
      FIRST_POST: firstPost,
      CREATED_AT: createdAtDate,
      LAST_POST: lastPost,
      BUMPED_AT: bumpedAtDate,
    });
  },

  @discourseComputed("created_at")
  createdAt(created_at) {
    return new Date(created_at);
  },

  @discourseComputed("tags")
  visibleListTags(tags) {
    if (!tags || !this.siteSettings.suppress_overlapping_tags_in_list) {
      return tags;
    }

    const title = this.title;
    const newTags = [];

    tags.forEach(function (tag) {
      if (title.toLowerCase().indexOf(tag) === -1) {
        newTags.push(tag);
      }
    });

    return newTags;
  },

  @discourseComputed("category_id")
  category(categoryId) {
    return Category.findById(categoryId);
  },

  @discourseComputed("reminder_at", "currentUser")
  formattedReminder(bookmarkReminderAt, currentUser) {
    return formattedReminderTime(
      bookmarkReminderAt,
      currentUser.resolvedTimezone(currentUser)
    ).capitalize();
  },

  @discourseComputed("linked_post_number", "fancy_title", "topic_id")
  topicLink(linked_post_number, fancy_title, id) {
    return Topic.create({ id, fancy_title, linked_post_number });
  },

  loadItems(params) {
    let url = `/u/${this.user.username}/bookmarks.json`;

    if (params) {
      url += "?" + $.param(params);
    }

    return ajax(url);
  },

  loadMore(additionalParams) {
    if (!this.more_bookmarks_url) {
      return Promise.resolve();
    }

    let moreUrl = this.more_bookmarks_url;
    if (moreUrl) {
      let [url, params] = moreUrl.split("?");
      moreUrl = url;
      if (params) {
        moreUrl += "?" + params;
      }
      if (additionalParams) {
        if (moreUrl.includes("?")) {
          moreUrl += "&" + $.param(additionalParams);
        } else {
          moreUrl += "?" + $.param(additionalParams);
        }
      }
    }

    return ajax({ url: moreUrl });
  },

  @discourseComputed(
    "post_user_username",
    "post_user_avatar_template",
    "post_user_name"
  )
  postUser(post_user_username, avatarTemplate, name) {
    return User.create({
      username: post_user_username,
      avatar_template: avatarTemplate,
      name: name,
    });
  },
});

Bookmark.reopenClass({
  create(args) {
    args = args || {};
    args.currentUser = args.currentUser || User.current();
    return this._super(args);
  },
});

export default Bookmark;
