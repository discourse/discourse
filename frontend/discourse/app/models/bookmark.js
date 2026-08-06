import { capitalize } from "@ember/string";
import { isEmpty } from "@ember/utils";
import { Promise } from "rsvp";
import {
  bulkBookmarkOperation,
  deleteBookmark,
  togglePinBookmark,
} from "discourse/data/builders/bookmarks";
import RestCompatModel from "discourse/data/rest-compat";
import { BookmarkSchema } from "discourse/data/schemas/bookmark";
import {
  defineFieldForwarders,
  warpStore,
} from "discourse/data/warp-rest-model";
import { formattedReminderTime } from "discourse/lib/bookmark";
import { longDate } from "discourse/lib/formatter";
import { getOwnerWithFallback } from "discourse/lib/get-owner";
import getURL from "discourse/lib/get-url";
import { applyModelTransformations } from "discourse/lib/model-transformers";
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

export default class Bookmark extends RestCompatModel {
  static type = "bookmark";
  static builders = { delete: deleteBookmark };

  // `user` is wrapped as a User instance (legacy parity); `currentUser` is
  // stashed on the wrapper as an own property (survives `_adoptResource` and
  // isn't part of the schema).
  static create(args = {}) {
    if (args instanceof Bookmark) {
      return args;
    }

    const { user, currentUser, ...rest } = args;
    const wrapper = super.create({ ...rest, user: User.create(user) });
    wrapper.currentUser = currentUser || User.current();
    return wrapper;
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
    return warpStore().request(
      bulkBookmarkOperation(
        bookmarks.map((b) => b.id),
        operation
      )
    );
  }

  static async applyTransformations(bookmarks) {
    await applyModelTransformations("bookmark", bookmarks);
  }

  get newBookmark() {
    return this.id == null;
  }

  get url() {
    return getURL(`/bookmarks/${this.id}`);
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
    return warpStore().request(togglePinBookmark(this.id));
  }

  pinAction() {
    return this.pinned ? "unpin" : "pin";
  }

  get lastPostUrl() {
    return this.topic_id
      ? this.urlForPostNumber(this.highest_post_number)
      : this.bookmarkable_url;
  }

  urlForPostNumber(postNumber) {
    let url = getURL(`/t/${this.topic_id}`);
    if (postNumber > 0) {
      url += `/${postNumber}`;
    }
    return url;
  }

  get bumpedAt() {
    return this.bumped_at ? new Date(this.bumped_at) : this.createdAt;
  }

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

  get timezone() {
    return this.currentUser?.user_option?.timezone || moment.tz.guess();
  }

  get reminderTitle() {
    if (!isEmpty(this.reminder_at)) {
      return i18n("bookmarks.created_with_reminder_generic", {
        date: formattedReminderTime(this.reminder_at, this.timezone),
        name: this.name || "",
      });
    }

    return i18n("bookmarks.created_generic", {
      name: this.name || "",
    });
  }

  get createdAt() {
    return new Date(this.created_at);
  }

  get visibleListTags() {
    const siteSettings = getOwnerWithFallback().lookup("service:site-settings");
    if (!this.tags || !siteSettings.suppress_overlapping_tags_in_list) {
      return this.tags;
    }

    const title = this.title;
    return this.tags.filter((tag) => !title.toLowerCase().includes(tag));
  }

  get category() {
    return Category.findById(this.category_id);
  }

  get formattedReminder() {
    return capitalize(formattedReminderTime(this.reminder_at, this.timezone));
  }

  get reminderAtExpired() {
    return moment(this.reminder_at) < moment();
  }

  // For topic-level bookmarks, no linked post number — let the topic-link
  // helper jump to the last unread post by default.
  get topicForList() {
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

  get bookmarkableTopicAlike() {
    return ["Topic", "Post"].includes(this.bookmarkable_type);
  }

  get hasMetadata() {
    return this.reminder_at || this.name;
  }
}

defineFieldForwarders(Bookmark, BookmarkSchema);
