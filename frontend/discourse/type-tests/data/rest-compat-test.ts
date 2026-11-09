import { expectTypeOf } from "expect-type";
import RestCompatModel from "discourse/data/rest-compat";
import Archetype from "discourse/models/archetype";
import Badge from "discourse/models/badge";
import Bookmark from "discourse/models/bookmark";
import Tag from "discourse/models/tag";
import TagGroup from "discourse/models/tag-group";
import TagInfo from "discourse/models/tag-info";
import TagNotification from "discourse/models/tag-notification";
import TagSettings from "discourse/models/tag-settings";
import TopicDetails from "discourse/models/topic-details";
import UserBadge from "discourse/models/user-badge";
import type StoreService from "discourse/services/store";

/** Independent of the exported aliases so missing types cannot mask failures. */
type ExpectedSaveResult<M> = {
  payload?: Record<string, unknown>;
  responseJson?: Record<string, unknown>;
  target?: M | null;
  [key: string]: unknown;
};

/** Rejects an untyped return without choosing a promise implementation. */
type IsPromise<T> = 0 extends 1 & T
  ? false
  : [T] extends [never]
    ? false
    : [T] extends [Promise<unknown>]
      ? true
      : false;

type PromiseResult<T> = IsPromise<T> extends true ? Awaited<T> : never;

class Widget extends RestCompatModel {
  static override type = "widget";

  static override munge(json: Record<string, unknown>) {
    return json;
  }

  declare id: number;
  declare name: string;

  override beforeCreate(props: object) {
    super.beforeCreate(props);
  }

  override beforeUpdate(props: object) {
    super.beforeUpdate(props);
  }

  override afterCreate(result: ExpectedSaveResult<Widget>) {
    super.afterCreate(result);
  }

  override afterUpdate(result: ExpectedSaveResult<Widget>) {
    super.afterUpdate(result);
  }
}

/* `create` returns the subclass and checks declared fields */

expectTypeOf(Widget.create()).toEqualTypeOf<Widget>();
expectTypeOf(Widget.create({ name: "x" })).toEqualTypeOf<Widget>();
/** Legacy callers pass payload keys the schema does not declare. */
expectTypeOf(Widget.create({ name: "x", extra: 1 })).toEqualTypeOf<Widget>();
// @ts-expect-error a declared field keeps its type
Widget.create({ name: 1 });

declare const store: StoreService;
Widget.create({ store, __type: "widget", __state: "new" });
// @ts-expect-error the store only assigns these states
Widget.create({ __state: "saved" });

declare const existing: Widget;
expectTypeOf(Widget.create(existing)).toEqualTypeOf<Widget>();

/* Store bookkeeping */

declare const widget: Widget;
expectTypeOf(widget.store).toEqualTypeOf<StoreService | undefined>();
expectTypeOf(widget.__type).toEqualTypeOf<string | undefined>();
expectTypeOf(widget.__state).toEqualTypeOf<"new" | "created" | undefined>();
expectTypeOf(widget.isSaving).toEqualTypeOf<boolean>();
expectTypeOf(widget.primaryKey).toEqualTypeOf<string>();
expectTypeOf(widget.isNew).toEqualTypeOf<boolean>();
expectTypeOf(widget.isCreated).toEqualTypeOf<boolean>();
expectTypeOf(widget.__isLocalDraft).toEqualTypeOf<boolean>();

/* Legacy `RestModel` surface */

expectTypeOf(widget.get("name")).toEqualTypeOf<string>();
expectTypeOf(widget.get("badge.name")).toEqualTypeOf<unknown>();

expectTypeOf(widget.set("name", "y")).toEqualTypeOf<string>();
// @ts-expect-error a declared field keeps its type
widget.set("name", 1);
/** Drafts and wrappers accept keys the schema does not declare. */
expectTypeOf(widget.set("undeclared", 5)).toEqualTypeOf<number>();

expectTypeOf(widget.getProperties("id", "name")).toEqualTypeOf<
  Pick<Widget, "id" | "name">
>();

expectTypeOf(widget.setProperties({ name: "y" })).toEqualTypeOf<{
  name: string;
}>();
// @ts-expect-error a declared field keeps its type
widget.setProperties({ name: 1 });

declare const saved: PromiseResult<ReturnType<Widget["save"]>>;
expectTypeOf(saved).not.toBeAny();
/** The legacy adapter path resolves to its result; the builder path to the record. */
expectTypeOf(saved).toExtend<Widget | ExpectedSaveResult<Widget>>();
expectTypeOf<Widget>().toExtend<typeof saved>();
widget.save();
widget.save({ name: "y" });

declare const updated: PromiseResult<ReturnType<Widget["update"]>>;
expectTypeOf(updated).not.toBeAny();
expectTypeOf(updated).toExtend<ExpectedSaveResult<Widget>>();
widget.update({ name: "y" });

expectTypeOf(widget.destroyRecord()).not.toBeAny();
expectTypeOf(widget.destroy()).resolves.toEqualTypeOf<void>();

/* Inherited factories return the subclass */

/** Calls, not `ReturnType`: that resolves a `this`-generic static against the base. */
const listing = Widget.findAll();
expectTypeOf(listing).resolves.toExtend<Widget[]>();
declare const listed: PromiseResult<typeof listing>;
expectTypeOf(listed[0]).toEqualTypeOf<Widget>();
const finding = Widget.findById(1);
expectTypeOf(finding).resolves.toEqualTypeOf<Widget>();
expectTypeOf(Widget.createFromJson({})).toExtend<Widget | Widget[]>();

/* A TopicDetails-shaped subclass: built from an id, resolving its own resource */

type DetailishAttrs = { id?: number | string | null; topic?: object };

class Detailish extends RestCompatModel {
  static override type = "detailish";

  static override create<C extends typeof Detailish>(
    this: C,
    attrs?: DetailishAttrs
  ): InstanceType<C>;

  static override create({ id }: DetailishAttrs = {}) {
    return new this(id);
  }

  topic: object | null = null;

  #topicId: string | null;
  #draft: Record<string, unknown> = {};

  constructor(topicId?: number | string | null) {
    super();
    this.#topicId = topicId == null ? null : String(topicId);
  }

  get id() {
    return this.#topicId;
  }

  override get __resource(): Record<string, unknown> | undefined {
    return this.#draft;
  }

  override updateFromJson(json: Record<string, unknown> | null): undefined {
    this.#draft = { ...json };
  }
}

expectTypeOf(Detailish.create({ id: 1 })).toEqualTypeOf<Detailish>();
expectTypeOf(Detailish.create()).toEqualTypeOf<Detailish>();
expectTypeOf(new Detailish(1).id).toEqualTypeOf<string | null>();

/* The JS subclasses inherit the typed factories */

expectTypeOf(Archetype.create({})).toEqualTypeOf<Archetype>();
expectTypeOf(Badge.create({})).toEqualTypeOf<Badge>();
const badgeListing = Badge.findAll();
expectTypeOf(badgeListing).resolves.toExtend<Badge[]>();
declare const badges: PromiseResult<typeof badgeListing>;
expectTypeOf(badges[0]).toEqualTypeOf<Badge>();
const badgeFinding = Badge.findById(1);
expectTypeOf(badgeFinding).resolves.toEqualTypeOf<Badge>();
expectTypeOf(UserBadge.createFromJson({})).toExtend<UserBadge | UserBadge[]>();
expectTypeOf(UserBadge.createFromJson({})).not.toBeAny();

/* The JS overrides of `create` return their own class */

expectTypeOf(Bookmark.create({})).toEqualTypeOf<Bookmark>();
expectTypeOf(TopicDetails.create({ id: 1 })).toEqualTypeOf<TopicDetails>();
expectTypeOf(Archetype.findById(1)).resolves.toEqualTypeOf<Archetype>();
expectTypeOf(Bookmark.findById(1)).resolves.toEqualTypeOf<Bookmark>();
expectTypeOf(Tag.findById(1)).resolves.toEqualTypeOf<Tag>();
expectTypeOf(TagGroup.findById(1)).resolves.toEqualTypeOf<TagGroup>();
expectTypeOf(TagInfo.findById(1)).resolves.toEqualTypeOf<TagInfo>();
expectTypeOf(
  TagNotification.findById(1)
).resolves.toEqualTypeOf<TagNotification>();
expectTypeOf(TagSettings.findById(1)).resolves.toEqualTypeOf<TagSettings>();
expectTypeOf(TopicDetails.findById(1)).resolves.toEqualTypeOf<TopicDetails>();
expectTypeOf(UserBadge.findById(1)).resolves.toEqualTypeOf<UserBadge>();

/** Subclasses of the JS overrides keep their own type. */
class SpecializedBookmark extends Bookmark {
  declare specialization: string;
}

class SpecializedDetails extends TopicDetails {
  declare specialization: string;
}

expectTypeOf(
  SpecializedBookmark.create({})
).toEqualTypeOf<SpecializedBookmark>();
expectTypeOf(
  SpecializedDetails.create({ id: 1 })
).toEqualTypeOf<SpecializedDetails>();
