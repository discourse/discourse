import categoryFromId from "discourse-common/utils/category-macro";
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
import { capitalize } from "@ember/string";

export const AUTO_DELETE_PREFERENCES = {
  NEVER: 0,
  CLEAR_REMINDER: 3,
  WHEN_REMINDER_SENT: 1,
  ON_OWNER_REPLY: 2,
};

export const NO_REMINDER_ICON = "bookmark";
export const WITH_REMINDER_ICON = "discourse-bookmark-clock";

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

  attachedTo() {
    return {
      target: this.bookmarkable_type.toLowerCase(),
      targetId: this.bookmarkable_id,
    };
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
      if (!title.toLowerCase().includes(tag)) {
        newTags.push(tag);
      }
    });

    return newTags;
  },

  category: categoryFromId("category_id"),

  @discourseComputed("reminder_at", "currentUser")
  formattedReminder(bookmarkReminderAt, currentUser) {
    return capitalize(
      formattedReminderTime(bookmarkReminderAt, currentUser.timezone)
    );
  },

  @discourseComputed("reminder_at")
  reminderAtExpired(bookmarkReminderAt) {
    return moment(bookmarkReminderAt) < moment();
  },

  @discourseComputed()
  topicForList() {
    // for topic level bookmarks we want to jump to the last unread post URL,
    // which the topic-link helper does by default if no linked post number is
    // provided
    const linkedPostNumber = this.for_topic ? null : this.linked_post_number;

    return Topic.create({
      id: this.topic_id,
      fancy_title: this.fancy_title,
      linked_post_number: linkedPostNumber,
      last_read_post_number: this.last_read_post_number,
      highest_post_number: this.highest_post_number,
    });
  },

  @discourseComputed("bookmarkable_type")
  bookmarkableTopicAlike(bookmarkable_type) {
    return ["Topic", "Post"].includes(bookmarkable_type);
  },
});

Bookmark.reopenClass({
  create(args) {
    args = args || {};
    args.currentUser = args.currentUser || User.current();
    args.user = User.create(args.user);
    return this._super(args);
  },
});

export default Bookmark;
