import type EmberObject from "@ember/object";
import { expectTypeOf } from "expect-type";
import Category from "discourse/models/category";
import Post from "discourse/models/post";
import PostActionType from "discourse/models/post-action-type";
import RestModel, {
  type RestModelAttrs,
  type RestModelSaveResult,
  type RestModelState,
  type RestModelStoreAttrs,
  type RestPayload,
} from "discourse/models/rest";
import UserDraft from "discourse/models/user-draft";
import type StoreService from "discourse/services/store";

type ExpectedStoreAttrs = {
  store?: StoreService;
  __type?: string;
  __state?: "new" | "created";
};

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

class TypedRestModel extends RestModel {
  static override munge(json: RestPayload): RestPayload {
    return json;
  }

  declare id: number;
  declare title: string;

  override beforeCreate(props: object) {
    super.beforeCreate(props);
  }

  override beforeUpdate(props: object) {
    super.beforeUpdate(props);
  }

  override afterCreate(result: RestModelSaveResult) {
    super.afterCreate(result);
  }

  override afterUpdate(result: RestModelSaveResult) {
    super.afterUpdate(result);
  }

  override createProperties(): RestPayload {
    return { title: this.title };
  }

  updateProperties(): RestPayload {
    return { title: this.title };
  }
}

class ParameterlessHooksRestModel extends TypedRestModel {
  override beforeCreate() {
    super.beforeCreate({});
  }

  override beforeUpdate() {
    super.beforeUpdate({});
  }

  override afterCreate() {
    super.afterCreate({});
  }

  override afterUpdate() {
    super.afterUpdate({});
  }
}

declare const store: StoreService;
declare const payload: Record<string, unknown>;

interface Payload {
  raw: string;
}

declare const interfacePayload: Payload;

// @ts-expect-error save-result targets must be RestModel instances
export type InvalidSaveResult = RestModelSaveResult<string>;

expectTypeOf<RestModelSaveResult<Post>["target"]>().toEqualTypeOf<
  Post | null | undefined
>();
expectTypeOf<RestModelSaveResult<Category>["target"]>().toEqualTypeOf<
  Category | null | undefined
>();

const model = RestModel.create();
const typedModel = TypedRestModel.create();
const userDraft = UserDraft.create();

/* Group with inferred factory types so missing exports cannot suppress all mismatches. */
expectTypeOf<{
  payload: RestPayload;
  state: RestModelState;
  storeAttrs: RestModelStoreAttrs;
  attrs: RestModelAttrs<TypedRestModel>;
  saveResult: RestModelSaveResult;
  typedSaveResult: RestModelSaveResult<TypedRestModel>;
  extra: RestModelSaveResult<TypedRestModel>["extra"];
  instance: typeof model;
}>().toEqualTypeOf<{
  payload: Record<string, unknown>;
  state: "new" | "created";
  storeAttrs: ExpectedStoreAttrs;
  attrs: Partial<TypedRestModel> &
    ExpectedStoreAttrs & { [key: string]: unknown };
  saveResult: ExpectedSaveResult<RestModel>;
  typedSaveResult: ExpectedSaveResult<TypedRestModel>;
  extra: unknown;
  instance: RestModel;
}>();

expectTypeOf(model).toEqualTypeOf<RestModel>();
expectTypeOf(model).extract<EmberObject>().toEqualTypeOf<RestModel>();
expectTypeOf(typedModel).toEqualTypeOf<TypedRestModel>();
expectTypeOf(typedModel).extract<RestModel>().toEqualTypeOf<TypedRestModel>();
expectTypeOf(userDraft).toEqualTypeOf<UserDraft>();
expectTypeOf(Category.create()).toEqualTypeOf<Category>();
expectTypeOf(Post.create({ raw: "hi" })).toEqualTypeOf<Post>();
expectTypeOf(
  PostActionType.create({ id: 1, name_key: "like" })
).toEqualTypeOf<PostActionType>();
expectTypeOf(
  ParameterlessHooksRestModel.create()
).toEqualTypeOf<ParameterlessHooksRestModel>();

expectTypeOf(
  RestModel.create({ store, __type: "rest", __state: "new" })
).toEqualTypeOf<RestModel>();
expectTypeOf(TypedRestModel.create({})).toEqualTypeOf<TypedRestModel>();
expectTypeOf(
  TypedRestModel.create({ title: "Draft" })
).toEqualTypeOf<TypedRestModel>();
expectTypeOf(
  TypedRestModel.create({
    id: 1,
    title: "Draft",
    store,
    __type: "typed-rest-model",
    __state: "created",
  })
).toEqualTypeOf<TypedRestModel>();
expectTypeOf(
  UserDraft.create({ store, __type: "user-draft", __state: "new" })
).toEqualTypeOf<UserDraft>();

expectTypeOf(
  RestModel.create({ unknownAttribute: true })
).toEqualTypeOf<RestModel>();
expectTypeOf(
  TypedRestModel.create({ title: "Draft", unknownAttribute: true })
).toEqualTypeOf<TypedRestModel>();
// @ts-expect-error create requires a constructor of RestModel instances
RestModel.create.call(class {}, {});
// @ts-expect-error a declared string field cannot receive a number
TypedRestModel.create({ title: 123 });
// @ts-expect-error a declared numeric field cannot receive a string
TypedRestModel.create({ id: "1" });
// @ts-expect-error store-assigned state has only two valid values
TypedRestModel.create({ __state: "deleted" });
// @ts-expect-error store-assigned model type must be a string
TypedRestModel.create({ __type: 123 });
// @ts-expect-error store must be a StoreService
TypedRestModel.create({ store: {} });

expectTypeOf(model.store).toEqualTypeOf<StoreService>();
expectTypeOf(model.__type).toEqualTypeOf<string | undefined>();
expectTypeOf(model.__state).toEqualTypeOf<"new" | "created" | undefined>();
expectTypeOf(model.isSaving).toEqualTypeOf<boolean>();
expectTypeOf(model.primaryKey).toEqualTypeOf<string>();
expectTypeOf(model.isNew).toEqualTypeOf<boolean>();
expectTypeOf(model.isCreated).toEqualTypeOf<boolean>();

expectTypeOf(model.update).parameters.toEqualTypeOf<[props?: object]>();
expectTypeOf(model.save).parameters.toEqualTypeOf<[props?: object]>();

export const update = model.update();
export const updateWithProps = model.update(payload);
export const updateWithInterfaceProps = model.update(interfacePayload);
export const save = model.save();
export const saveWithProps = model.save(payload);
export const saveWithInterfaceProps = model.save(interfacePayload);
export const typedUpdate = typedModel.update();
export const typedUpdateWithProps = typedModel.update(payload);
export const typedSave = typedModel.save();
export const typedSaveWithProps = typedModel.save(payload);
export const draftUpdate = userDraft.update(payload);
export const draftSave = userDraft.save(payload);

expectTypeOf<PromiseResult<typeof update>>().toEqualTypeOf<
  ExpectedSaveResult<RestModel>
>();
expectTypeOf<PromiseResult<typeof updateWithProps>>().toEqualTypeOf<
  ExpectedSaveResult<RestModel>
>();
expectTypeOf<PromiseResult<typeof updateWithInterfaceProps>>().toEqualTypeOf<
  ExpectedSaveResult<RestModel>
>();
expectTypeOf<PromiseResult<typeof save>>().toEqualTypeOf<
  ExpectedSaveResult<RestModel>
>();
expectTypeOf<PromiseResult<typeof saveWithProps>>().toEqualTypeOf<
  ExpectedSaveResult<RestModel>
>();
expectTypeOf<PromiseResult<typeof saveWithInterfaceProps>>().toEqualTypeOf<
  ExpectedSaveResult<RestModel>
>();
expectTypeOf<PromiseResult<typeof typedUpdate>>().toEqualTypeOf<
  ExpectedSaveResult<TypedRestModel>
>();
expectTypeOf<PromiseResult<typeof typedUpdateWithProps>>().toEqualTypeOf<
  ExpectedSaveResult<TypedRestModel>
>();
expectTypeOf<PromiseResult<typeof typedSave>>().toEqualTypeOf<
  ExpectedSaveResult<TypedRestModel>
>();
expectTypeOf<PromiseResult<typeof typedSaveWithProps>>().toEqualTypeOf<
  ExpectedSaveResult<TypedRestModel>
>();
expectTypeOf<PromiseResult<typeof draftUpdate>>().toEqualTypeOf<
  ExpectedSaveResult<UserDraft>
>();
expectTypeOf<PromiseResult<typeof draftSave>>().toEqualTypeOf<
  ExpectedSaveResult<UserDraft>
>();
expectTypeOf<
  IsPromise<ReturnType<typeof model.destroyRecord>>
>().toEqualTypeOf<true>();

// @ts-expect-error update accepts a payload object
model.update("invalid");
// @ts-expect-error save accepts a payload object
model.save(123);

expectTypeOf(model.beforeCreate).parameters.toEqualTypeOf<[props: object]>();
expectTypeOf(model.beforeUpdate).parameters.toEqualTypeOf<[props: object]>();
expectTypeOf(model.afterCreate).parameters.toEqualTypeOf<
  [result: ExpectedSaveResult<RestModel>]
>();
expectTypeOf(model.afterUpdate).parameters.toEqualTypeOf<
  [result: ExpectedSaveResult<RestModel>]
>();
expectTypeOf(RestModel.munge).parameters.toEqualTypeOf<
  [json: Record<string, unknown>, store?: StoreService]
>();
expectTypeOf(RestModel.munge(payload)).toEqualTypeOf<Record<string, unknown>>();
expectTypeOf(RestModel.munge(payload, store)).toEqualTypeOf<
  Record<string, unknown>
>();
expectTypeOf<
  [ReturnType<typeof TypedRestModel.munge>, typeof typedModel]
>().toEqualTypeOf<[Record<string, unknown>, TypedRestModel]>();
expectTypeOf(model.createProperties()).toEqualTypeOf<Record<string, unknown>>();
expectTypeOf(typedModel.createProperties()).toEqualTypeOf<
  Record<string, unknown>
>();
expectTypeOf(typedModel.updateProperties()).toEqualTypeOf<
  Record<string, unknown>
>();

// @ts-expect-error munge accepts a payload object
RestModel.munge("invalid");
// @ts-expect-error munge's optional store must be a StoreService
RestModel.munge(payload, {});
