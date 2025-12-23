import { computed } from "@ember/object";
import { none } from "@ember/object/computed";
import { capitalize } from "@ember/string";
import { isEmpty } from "@ember/utils";
import { Promise } from "rsvp";
import { ajax } from "discourse/lib/ajax";
import { formattedReminderTime } from "discourse/lib/bookmark";
import { longDate } from "discourse/lib/formatter";
import getURL from "discourse/lib/get-url";
import { applyModelTransformations } from "discourse/lib/model-transformers";
import RestModel from "discourse/models/rest";
import Topic from "discourse/models/topic";
import User from "discourse/models/user";
import { i18n } from "discourse-i18n";
import Category from "./category";

export const AUTO_DELETE_PREFERENCES = {
  NEVER: 0,
  CLEAR_REMINDER: 3,
  WHEN_REMINDER_SENT: 1,
  ON_OWNER_REPLY: 2,
};

export const NO_REMINDER_ICON = "bookmark";
export const NOT_BOOKMARKED = "far-bookmark";
export const WITH_REMINDER_ICON = "discourse-bookmark-clock";

export default class Bookmark extends RestModel {
  static create(args) {
    args = args || {};
    args.currentUser = args.currentUser || User.current();
    args.user = User.create(args.user);
    return super.create(args);
  }

  static createFor(user, bookmarkableType, bookmarkableId) {
    return Bookmark.create({
      bookmarkable_type: bookmarkableType,
      bookmarkable_id: bookmarkableId,
      user_id: user.id,
      auto_delete_preference: user.user_option.bookmark_auto_delete_preference,
    });
  }

  static bulkOperation(bookmarks, operation) {
    const data = {
      bookmark_ids: bookmarks.map((item) => item.id),
      operation,
    };

    return ajax("/bookmarks/bulk", {
      type: "PUT",
      data,
    });
  }

  static async applyTransformations(bookmarks) {
    await applyModelTransformations("bookmark", bookmarks);
  }

  @none("id") newBookmark;

  @computed
  get url() {
    return getURL(`/bookmarks/${this.id}`);
  }

  destroy() {
    if (this.newBookmark) {
      return Promise.resolve();
    }

    return ajax(this.url, {
      type: "DELETE",
    });
  }

  attachedTo() {
    return {
      target: this.bookmarkable_type.toLowerCase(),
      targetId: this.bookmarkable_id,
    };
  }

  togglePin() {
    if (this.newBookmark) {
      return Promise.resolve();
    }

    return ajax(this.url + "/toggle_pin", {
      type: "PUT",
    });
  }

  pinAction() {
    return this.pinned ? "unpin" : "pin";
  }

  @computed("highest_post_number", "url")
  get lastPostUrl() {
    return this.urlForPostNumber(this.highest_post_number);
  }

  // Helper to build a Url with a post number
  urlForPostNumber(postNumber) {
    let url = getURL(`/t/${this.topic_id}`);
    if (postNumber > 0) {
      url += `/${postNumber}`;
    }
    return url;
  }

  // returns createdAt if there's no bumped date
  @computed("bumped_at", "createdAt")
  get bumpedAt() {
    if (this.bumped_at) {
      return new Date(this.bumped_at);
    } else {
      return this.createdAt;
    }
  }

  @computed("bumpedAt", "createdAt")
  get bumpedAtTitle() {
    const BUMPED_FORMAT = "YYYY-MM-DDTHH:mm:ss";
    if (moment(this.bumpedAt).isValid() && moment(this.createdAt).isValid()) {
      const bumpedAtStr = moment(this.bumpedAt).format(BUMPED_FORMAT);
      const createdAtStr = moment(this.createdAt).format(BUMPED_FORMAT);

      return bumpedAtStr !== createdAtStr
        ? `${i18n("topic.created_at", {
            date: longDate(this.createdAt),
          })}\n${i18n("topic.bumped_at", { date: longDate(this.bumpedAt) })}`
        : i18n("topic.created_at", { date: longDate(this.createdAt) });
    }
  }

  @computed("name", "reminder_at")
  get reminderTitle() {
    if (!isEmpty(this.reminder_at)) {
      return i18n("bookmarks.created_with_reminder_generic", {
        date: formattedReminderTime(
          this.reminder_at,
          this.currentUser?.user_option?.timezone || moment.tz.guess()
        ),
        name: this.name || "",
      });
    }

    return i18n("bookmarks.created_generic", {
      name: this.name || "",
    });
  }

  @computed("created_at")
  get createdAt() {
    return new Date(this.created_at);
  }

  @computed("tags")
  get visibleListTags() {
    if (!this.tags || !this.siteSettings.suppress_overlapping_tags_in_list) {
      return this.tags;
    }

    const title = this.title;
    const newTags = [];

    this.tags.forEach(function (tag) {
      if (!title.toLowerCase().includes(tag)) {
        newTags.push(tag);
      }
    });

    return newTags;
  }

  @computed("category_id")
  get category() {
    return Category.findById(this.category_id);
  }

  @computed("reminder_at", "currentUser")
  get formattedReminder() {
    return capitalize(
      formattedReminderTime(
        this.reminder_at,
        this.currentUser?.user_option?.timezone || moment.tz.guess()
      )
    );
  }

  @computed("reminder_at")
  get reminderAtExpired() {
    return moment(this.reminder_at) < moment();
  }

  @computed()
  get topicForList() {
    // for topic level bookmarks we want to jump to the last unread post URL,
    // which the topic-link helper does by default if no linked post number is
    // provided
    const linkedPostNumber =
      this.bookmarkable_type === "Topic" ? null : this.linked_post_number;

    return Topic.create({
      id: this.topic_id,
      fancy_title: this.fancy_title,
      linked_post_number: linkedPostNumber,
      last_read_post_number: this.last_read_post_number,
      highest_post_number: this.highest_post_number,
    });
  }

  @computed("bookmarkable_type")
  get bookmarkableTopicAlike() {
    return ["Topic", "Post"].includes(this.bookmarkable_type);
  }

  @computed("reminder_at", "name")
  get hasMetadata() {
    return this.reminder_at || this.name;
  }
}
