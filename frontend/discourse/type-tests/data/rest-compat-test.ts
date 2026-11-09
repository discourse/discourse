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

class Gadget extends RestCompatModel {
  static override type = "gadget";

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

  override afterCreate(result: ExpectedSaveResult<Gadget>) {
    super.afterCreate(result);
  }

  override afterUpdate(result: ExpectedSaveResult<Gadget>) {
    super.afterUpdate(result);
  }
}

/* `create` returns the subclass and checks declared fields */

expectTypeOf(Gadget.create()).toEqualTypeOf<Gadget>();
expectTypeOf(Gadget.create({ name: "x" })).toEqualTypeOf<Gadget>();
/** Legacy callers pass payload keys the schema does not declare. */
expectTypeOf(Gadget.create({ name: "x", extra: 1 })).toEqualTypeOf<Gadget>();
// @ts-expect-error a declared field keeps its type
Gadget.create({ name: 1 });

declare const store: StoreService;
Gadget.create({ store, __type: "gadget", __state: "new" });
// @ts-expect-error the store only assigns these states
Gadget.create({ __state: "saved" });

declare const existing: Gadget;
expectTypeOf(Gadget.create(existing)).toEqualTypeOf<Gadget>();

/* Store bookkeeping */

declare const gadget: Gadget;
expectTypeOf(gadget.store).toEqualTypeOf<StoreService | undefined>();
expectTypeOf(gadget.__type).toEqualTypeOf<string | undefined>();
expectTypeOf(gadget.__state).toEqualTypeOf<"new" | "created" | undefined>();
expectTypeOf(gadget.isSaving).toEqualTypeOf<boolean>();
expectTypeOf(gadget.primaryKey).toEqualTypeOf<string>();
expectTypeOf(gadget.isNew).toEqualTypeOf<boolean>();
expectTypeOf(gadget.isCreated).toEqualTypeOf<boolean>();
expectTypeOf(gadget.__isLocalDraft).toEqualTypeOf<boolean>();

/* Legacy `RestModel` surface */

expectTypeOf(gadget.get("name")).toEqualTypeOf<string>();
expectTypeOf(gadget.get("badge.name")).toEqualTypeOf<unknown>();

expectTypeOf(gadget.set("name", "y")).toEqualTypeOf<string>();
// @ts-expect-error a declared field keeps its type
gadget.set("name", 1);
/** Drafts and wrappers accept keys the schema does not declare. */
expectTypeOf(gadget.set("undeclared", 5)).toEqualTypeOf<number>();

expectTypeOf(gadget.getProperties("id", "name")).toEqualTypeOf<
  Pick<Gadget, "id" | "name">
>();

expectTypeOf(gadget.setProperties({ name: "y" })).toEqualTypeOf<{
  name: string;
}>();
// @ts-expect-error a declared field keeps its type
gadget.setProperties({ name: 1 });

declare const saved: PromiseResult<ReturnType<Gadget["save"]>>;
expectTypeOf(saved).not.toBeAny();
/** The legacy adapter path resolves to its result; the builder path to the record. */
expectTypeOf(saved).toExtend<Gadget | ExpectedSaveResult<Gadget>>();
expectTypeOf<Gadget>().toExtend<typeof saved>();
gadget.save();
gadget.save({ name: "y" });

declare const updated: PromiseResult<ReturnType<Gadget["update"]>>;
expectTypeOf(updated).not.toBeAny();
expectTypeOf(updated).toExtend<ExpectedSaveResult<Gadget>>();
gadget.update({ name: "y" });

expectTypeOf(gadget.destroyRecord()).not.toBeAny();
expectTypeOf(gadget.destroy()).resolves.toEqualTypeOf<void>();

/* Inherited factories return the subclass */

/** Calls, not `ReturnType`: that resolves a `this`-generic static against the base. */
const listing = Gadget.findAll();
expectTypeOf(listing).resolves.toExtend<Gadget[]>();
declare const listed: PromiseResult<typeof listing>;
expectTypeOf(listed[0]).toEqualTypeOf<Gadget>();
const finding = Gadget.findById(1);
expectTypeOf(finding).resolves.toEqualTypeOf<Gadget>();
expectTypeOf(Gadget.createFromJson({})).toExtend<Gadget | Gadget[]>();

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
