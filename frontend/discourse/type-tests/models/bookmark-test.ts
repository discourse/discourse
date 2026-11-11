import type EmberObject from "@ember/object";
import { expectTypeOf } from "expect-type";
import RestCompatModel from "discourse/data/rest-compat";
import Bookmark, {
  AUTO_DELETE_PREFERENCES,
  type BookmarkFields,
} from "discourse/models/bookmark";
import type Category from "discourse/models/category";
import type Topic from "discourse/models/topic";
import type User from "discourse/models/user";
import type {
  default as StoreService,
  ModelFor,
} from "discourse/services/store";

declare const store: StoreService;
declare const bookmark: Bookmark;
declare const user: User;
declare const topic: Topic;

interface ExpectedBookmarkTag {
  id: number;
  name: string;
  slug: string;
}

/**
 * Fields across the user bookmark list rows, the user menu rows, the topic
 * view's `TopicViewBookmarkSerializer` rows and local drafts. Every field is
 * optional because drafts carry only the bookmarkable and its owner.
 */
interface ExpectedBookmarkFields {
  id?: number;
  name?: string | null;
  created_at?: string;
  updated_at?: string;
  reminder_at?: string | null;
  /** Sent only with a reminder. */
  reminder_at_ics_start?: string;
  reminder_at_ics_end?: string;
  pinned?: boolean | null;
  /** Plugin bookmarkables may have no title. */
  title?: string | null;
  fancy_title?: string | null;
  fancy_title_localized?: boolean;
  locale?: string | null;
  excerpt?: string | null;
  /** Validated present on every saved bookmark. */
  bookmarkable_id?: number;
  /** Plugins register their own bookmarkable types. */
  bookmarkable_type?: string;
  bookmarkable_url?: string;
  topic_id?: number;
  linked_post_number?: number | null;
  deleted?: boolean;
  hidden?: boolean;
  category_id?: number | null;
  closed?: boolean;
  archived?: boolean;
  archetype?: string;
  highest_post_number?: number;
  bumped_at?: string;
  slug?: string | null;
  tags?: ExpectedBookmarkTag[];
  tags_descriptions?: Record<string, string>;
  /** Emitted only when true. */
  truncated?: true;
  /** A left join leaves topic-level bookmarks without a post number. */
  post_number?: number | null;
  last_read_post_number?: number | null;
  /** `create` always wraps the payload user. */
  user?: User;
  auto_delete_preference?: number;
  user_id?: number;
}

/** A `BasicUserSerializer` payload, as list rows embed it. */
interface ExpectedBookmarkUserPayload {
  id: number;
  username: string;
  name?: string | null;
  avatar_template: string;
}

declare module "discourse/models/bookmark" {
  interface BookmarkFields {
    type_test_plugin_flag?: boolean;
  }
}

expectTypeOf(bookmark).toExtend<RestCompatModel>();
expectTypeOf(bookmark).not.toBeAny();
expectTypeOf<ModelFor<"bookmark">>().toEqualTypeOf<Bookmark>();
expectTypeOf(
  store.createRecord("bookmark", { bookmarkable_type: "Post" })
).toEqualTypeOf<Bookmark>();

/* Fields. */

expectTypeOf<
  Omit<BookmarkFields, "type_test_plugin_flag">
>().toEqualTypeOf<ExpectedBookmarkFields>();
expectTypeOf<
  Pick<Bookmark, keyof ExpectedBookmarkFields>
>().toEqualTypeOf<ExpectedBookmarkFields>();
expectTypeOf(bookmark.type_test_plugin_flag).toEqualTypeOf<
  boolean | undefined
>();
// The schema forwards these, but no serializer sends them.
expectTypeOf<BookmarkFields>().not.toHaveProperty("post_id");
expectTypeOf<BookmarkFields>().not.toHaveProperty("is_warning");
expectTypeOf<BookmarkFields>().not.toHaveProperty("invisible");
// Plugins add these; core does not declare them.
expectTypeOf<BookmarkFields>().not.toHaveProperty("assigned_to_user");
expectTypeOf<BookmarkFields>().not.toHaveProperty("assigned_to_group");

bookmark.name = "Later";
bookmark.reminder_at = null;
bookmark.auto_delete_preference = AUTO_DELETE_PREFERENCES.CLEAR_REMINDER;
// @ts-expect-error bookmarkable ids are numbers
bookmark.bookmarkable_id = "1";

/* Client state. */

expectTypeOf(bookmark.currentUser).toEqualTypeOf<User | null>();
// The bookmark list attaches the row's topic status for its status icons.
expectTypeOf(bookmark.topicStatus).not.toBeAny();
expectTypeOf(bookmark.topicStatus).toExtend<EmberObject | undefined>();
expectTypeOf<NonNullable<Bookmark["topicStatus"]>["closed"]>().toEqualTypeOf<
  boolean | undefined
>();
expectTypeOf<NonNullable<Bookmark["topicStatus"]>["archived"]>().toEqualTypeOf<
  boolean | undefined
>();
expectTypeOf(AUTO_DELETE_PREFERENCES.NEVER).toExtend<number>();

/* Derived state. */

expectTypeOf(bookmark.newBookmark).toEqualTypeOf<boolean>();
expectTypeOf(bookmark.url).toEqualTypeOf<string>();
expectTypeOf(bookmark.lastPostUrl).toEqualTypeOf<string | undefined>();
expectTypeOf(bookmark.bumpedAt).toEqualTypeOf<Date>();
expectTypeOf(bookmark.bumpedAtTitle).toEqualTypeOf<string | undefined>();
expectTypeOf(bookmark.timezone).toEqualTypeOf<string>();
expectTypeOf(bookmark.reminderTitle).toEqualTypeOf<string>();
expectTypeOf(bookmark.createdAt).toEqualTypeOf<Date>();
expectTypeOf(bookmark.visibleListTags).toEqualTypeOf<
  ExpectedBookmarkTag[] | undefined
>();
expectTypeOf(bookmark.category).toEqualTypeOf<Category | undefined>();
expectTypeOf(bookmark.formattedReminder).toEqualTypeOf<string>();
expectTypeOf(bookmark.reminderAtExpired).toEqualTypeOf<boolean>();
expectTypeOf(bookmark.topicForList).toEqualTypeOf<Topic>();
expectTypeOf(bookmark.bookmarkableTopicAlike).toEqualTypeOf<boolean>();
expectTypeOf(bookmark.hasMetadata).toEqualTypeOf<string | null | undefined>();

/* Actions. */

expectTypeOf(bookmark.attachedTo()).toEqualTypeOf<{
  target: string;
  targetId: number | undefined;
}>();
expectTypeOf(bookmark.togglePin()).not.toBeAny();
expectTypeOf(bookmark.togglePin()).toExtend<PromiseLike<unknown>>();
expectTypeOf(bookmark.pinAction()).toEqualTypeOf<"pin" | "unpin">();
expectTypeOf(bookmark.urlForPostNumber(3)).toEqualTypeOf<string>();

/** Audit only what Bookmark adds over its base. */
type AnyKeys<T> = {
  [K in keyof T]-?: 0 extends 1 & T[K] ? K : never;
}[keyof T];
type AnyReturnKeys<T> = {
  [K in keyof T]-?: T[K] extends (...args: never) => infer R
    ? 0 extends 1 & R
      ? K
      : never
    : never;
}[keyof T];
type OwnAnyKeys<T, Base> = Exclude<
  AnyKeys<T> | AnyReturnKeys<T>,
  AnyKeys<Base> | AnyReturnKeys<Base>
>;
expectTypeOf<OwnAnyKeys<Bookmark, RestCompatModel>>().toEqualTypeOf<never>();

/* Construction: `create` wraps the payload user and records the viewer. */

declare const userPayload: ExpectedBookmarkUserPayload;
expectTypeOf(
  Bookmark.create({
    id: 1,
    bookmarkable_type: "Post",
    bookmarkable_id: 2,
    user: userPayload,
  })
).toEqualTypeOf<Bookmark>();
expectTypeOf(Bookmark.create({ user })).toEqualTypeOf<Bookmark>();
expectTypeOf(
  Bookmark.create({ id: 1, currentUser: user })
).toEqualTypeOf<Bookmark>();
expectTypeOf(Bookmark.create()).toEqualTypeOf<Bookmark>();
expectTypeOf(Bookmark.create(bookmark)).toEqualTypeOf<Bookmark>();
// @ts-expect-error bookmarkable ids are numbers
Bookmark.create({ bookmarkable_id: "2" });

expectTypeOf(
  Bookmark.createFor(user, "Topic", topic.id)
).toEqualTypeOf<Bookmark>();
expectTypeOf(Bookmark.bulkOperation([bookmark], "delete")).not.toBeAny();
expectTypeOf(
  Bookmark.applyTransformations([bookmark])
).resolves.toEqualTypeOf<void>();

/* Consumers: topic bookmarks are read without casts. */

const topicBookmark = topic.bookmarks[0];
expectTypeOf(topicBookmark.id).toEqualTypeOf<number | undefined>();
expectTypeOf(topicBookmark.bookmarkable_type).toEqualTypeOf<
  string | undefined
>();
expectTypeOf(topicBookmark.bookmarkable_id).toEqualTypeOf<number | undefined>();
expectTypeOf(user.bookmarks).toEqualTypeOf<Bookmark>();
