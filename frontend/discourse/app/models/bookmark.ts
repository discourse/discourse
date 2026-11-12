import type EmberObject from "@ember/object";
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
import type { RestModelStoreAttrs } from "discourse/models/rest";
import Topic from "discourse/models/topic";
import User, { type UserCreateAttrs } from "discourse/models/user";
import type WarpStore from "discourse/services/warp-store";
import { i18n } from "discourse-i18n";
import Category from "./category.ts";

/** TopicTagsMixin list-row tags; visibility depends on the viewer. */
export interface BookmarkTag {
  id: number;
  name: string;
  slug: string;
}

/**
 * Fields from the user bookmark list, the user menu and the topic view serializers.
 * All are optional: a new bookmark starts with only its bookmarkable and owner.
 */
export interface BookmarkFields {
  id?: number;
  name?: string | null;
  /** List rows only. */
  created_at?: string;
  updated_at?: string;
  reminder_at?: string | null;
  /** Sent only with a reminder. */
  reminder_at_ics_start?: string;
  /** The reminder plus one hour; sent only with a reminder. */
  reminder_at_ics_end?: string;
  /** The column is nullable despite its default. */
  pinned?: boolean | null;
  /** Null for bookmarkables without a title. */
  title?: string | null;
  fancy_title?: string | null;
  /** Sent only with content localization. */
  fancy_title_localized?: boolean;
  /** Sent only with content localization. */
  locale?: string | null;
  /** Omitted when the viewer cannot see the bookmarked content. */
  excerpt?: string | null;
  /** Validated present on every saved bookmark. */
  bookmarkable_id?: number;
  /** Bookmarkable types are registered at runtime, not only posts and topics. */
  bookmarkable_type?: string;
  bookmarkable_url?: string;
  /** Post and topic list rows only. */
  topic_id?: number;
  linked_post_number?: number | null;
  deleted?: boolean;
  hidden?: boolean;
  /** Private-message topics may have no category. */
  category_id?: number | null;
  closed?: boolean;
  archived?: boolean;
  archetype?: string;
  highest_post_number?: number;
  bumped_at?: string;
  slug?: string | null;
  /** Sent only when the viewer can see the topic's tags. */
  tags?: BookmarkTag[];
  /** Tags without a description are left out. */
  tags_descriptions?: Record<string, string>;
  /** Sent only when true. */
  truncated?: true;
  /** A left join leaves topic-level bookmarks without a post number. */
  post_number?: number | null;
  /** Topic list rows only; null without a read position. */
  last_read_post_number?: number | null;
  /** `create` always wraps the payload user. */
  user?: User;
  /** Sent by the topic view; set locally on new bookmarks. */
  auto_delete_preference?: number;
  /** Client-only: set by `createFor`. */
  user_id?: number;
}

/** Creation wraps embedded users before exposing the schema fields. */
export type BookmarkCreateAttrs<M = Bookmark> = Partial<Omit<M, "user">> &
  RestModelStoreAttrs & {
    user?: User | UserCreateAttrs;
  };

export const AUTO_DELETE_PREFERENCES = {
  NEVER: 0,
  CLEAR_REMINDER: 3,
  WHEN_REMINDER_SENT: 1,
  ON_OWNER_REPLY: 2,
};

export const NO_REMINDER_ICON = "bookmark";
export const NOT_BOOKMARKED = "far-bookmark";
export const WITH_REMINDER_ICON = "discourse-bookmark-clock";

/** Schema forwarders expose these fields without adding instance properties. */
// eslint-disable-next-line @typescript-eslint/no-empty-object-type, @typescript-eslint/no-unsafe-declaration-merging
export default interface Bookmark extends BookmarkFields {}

// eslint-disable-next-line @typescript-eslint/no-unsafe-declaration-merging
export default class Bookmark extends RestCompatModel {
  static override type = "bookmark";
  static override builders = { delete: deleteBookmark };

  /**
   * `user` is wrapped as a User instance (legacy parity); `currentUser` is
   * stashed on the wrapper as an own property (survives `_adoptResource` and
   * isn't part of the schema).
   */
  static override create<
    C extends abstract new (...args: never[]) => RestCompatModel,
  >(
    this: C,
    args?: BookmarkCreateAttrs<InstanceType<C>> | InstanceType<C>
  ): InstanceType<C>;

  static override create<C extends typeof RestCompatModel>(
    this: C,
    args?: BookmarkCreateAttrs<InstanceType<C>> | InstanceType<C>
  ): InstanceType<C>;

  static override create(args: BookmarkCreateAttrs = {}) {
    if (args instanceof Bookmark) {
      return args;
    }

    const { user, currentUser, ...rest } = args;
    const wrapper = super.create({
      ...rest,
      user: User.create(user),
    }) as Bookmark;
    wrapper.currentUser = currentUser || User.current();
    return wrapper;
  }

  static createFor(
    user: User,
    bookmarkableType: string,
    bookmarkableId: number
  ) {
    return Bookmark.create({
      bookmarkable_type: bookmarkableType,
      bookmarkable_id: bookmarkableId,
      user_id: user.id,
      auto_delete_preference: user.user_option!.bookmark_auto_delete_preference,
    });
  }

  static bulkOperation(
    bookmarks: Bookmark[],
    operation: string | { type: string; [key: string]: unknown }
  ) {
    return warpStore().request(
      bulkBookmarkOperation(
        bookmarks.map((b) => b.id),
        operation
      ) as Parameters<WarpStore["request"]>[0]
    );
  }

  static async applyTransformations(bookmarks: Bookmark[]) {
    await applyModelTransformations("bookmark", bookmarks);
  }

  declare id?: number;

  /** The viewing user, set by `create`. */
  declare currentUser: User | null;

  /** Set on list rows by the bookmark list controller. */
  declare topicStatus?: EmberObject & {
    closed?: boolean;
    archived?: boolean;
    /** No serializer sends these. */
    is_warning?: unknown;
    invisible?: unknown;
    pinned: false;
    unpinned: false;
  };

  #topicForList: Topic | undefined;

  #siteSettings: { suppress_overlapping_tags_in_list?: boolean } | undefined;

  get newBookmark() {
    return this.id == null;
  }

  get url(): string {
    return getURL(`/bookmarks/${this.id}`);
  }

  get lastPostUrl(): string | undefined {
    return this.topic_id
      ? this.urlForPostNumber(this.highest_post_number)
      : this.bookmarkable_url;
  }

  get bumpedAt() {
    return this.bumped_at ? new Date(this.bumped_at) : this.createdAt;
  }

  get bumpedAtTitle(): string | undefined {
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

  get reminderTitle(): string {
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
    return new Date(this.created_at!);
  }

  // Read per row on the bookmark list — cache the service lookup.
  get visibleListTags() {
    const tags = this.tags;
    this.#siteSettings ??= getOwnerWithFallback().lookup(
      "service:site-settings"
    ) as { suppress_overlapping_tags_in_list?: boolean };
    if (!tags || !this.#siteSettings!.suppress_overlapping_tags_in_list) {
      return tags;
    }

    const title = this.title!.toLowerCase();
    // Deliberately preserve the existing object-to-string comparison.
    return tags.filter((tag) => !title.includes(tag as unknown as string));
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
  //
  // Built once: read from a list row, where a fresh `Topic` per read would fire
  // `init` callbacks on every rerender and hand out a new identity each time.
  get topicForList() {
    return (this.#topicForList ??= Topic.create({
      id: this.topic_id,
      fancy_title: this.fancy_title!,
      linked_post_number:
        this.bookmarkable_type === "Topic" ? null : this.linked_post_number,
      last_read_post_number: this.last_read_post_number,
      highest_post_number: this.highest_post_number,
    }));
  }

  get bookmarkableTopicAlike() {
    return ["Topic", "Post"].includes(this.bookmarkable_type!);
  }

  get hasMetadata() {
    return this.reminder_at || this.name;
  }

  attachedTo() {
    return {
      target: this.bookmarkable_type!.toLowerCase(),
      targetId: this.bookmarkable_id,
    };
  }

  togglePin() {
    if (this.newBookmark) {
      return Promise.resolve();
    }
    return warpStore().request(
      togglePinBookmark(this.id) as Parameters<WarpStore["request"]>[0]
    );
  }

  pinAction(): "pin" | "unpin" {
    return this.pinned ? "unpin" : "pin";
  }

  urlForPostNumber(postNumber: number | undefined): string {
    let url = getURL(`/t/${this.topic_id}`);
    if (postNumber! > 0) {
      url += `/${postNumber}`;
    }
    return url;
  }
}

defineFieldForwarders(Bookmark, BookmarkSchema);

declare const moment: typeof import("moment");
