import type { TrustedHTML } from "@ember/template";
import { expectTypeOf } from "expect-type";
import type Category from "discourse/models/category";
import type RestModel from "discourse/models/rest";
import type User from "discourse/models/user";
import UserDraft, {
  type UserDraftData,
  type UserDraftFields,
} from "discourse/models/user-draft";
import type {
  default as StoreService,
  ModelFor,
} from "discourse/services/store";

/** Keep expectations independent of the model's exported field definitions. */
interface ExpectedUserDraftData {
  reply?: string | null;
  action?: string;
  title?: string | null;
  categoryId?: number | null;
  postId?: number;
  [key: string]: unknown;
}

interface ExpectedUserDraftFields {
  created_at: string;
  draft_key: string;
  sequence: number;
  draft_username: string;
  avatar_template: string;
  data: ExpectedUserDraftData;
  topic_id: number | null;
  username: string;
  username_lower: string;
  name?: string | null;
  user_id: number;
  title?: string | null;
  slug?: string;
  category_id?: number;
  closed?: true;
  archetype: string | null;
  archived?: true;
  excerpt: string;
  truncated?: true;
  post_number: number | null;
  category?: Category | null;
}

declare module "discourse/models/user-draft" {
  /** Redeclaring an existing member also rejects a non-mergeable type alias. */
  interface UserDraftData {
    reply?: string | null;
  }

  interface UserDraftFields {
    typeTestPluginRating?: number;
  }
}

declare const store: StoreService;
declare const category: Category;
declare const user: User;
declare const fields: ExpectedUserDraftFields;
declare const data: UserDraftData;

expectTypeOf<UserDraftData>().toEqualTypeOf<ExpectedUserDraftData>();
expectTypeOf<UserDraftData>().not.toBeAny();
expectTypeOf(data.reply).toEqualTypeOf<string | null | undefined>();
expectTypeOf(data.action).toEqualTypeOf<string | undefined>();
expectTypeOf(data.title).toEqualTypeOf<string | null | undefined>();
expectTypeOf(data.categoryId).toEqualTypeOf<number | null | undefined>();
expectTypeOf(data.postId).toEqualTypeOf<number | undefined>();
expectTypeOf(data["plugin_payload"]).toEqualTypeOf<unknown>();
expectTypeOf(data["plugin_payload"]).not.toBeAny();

export const minimalData: UserDraftData = { reply: "Draft" };
export const populatedData: UserDraftData = {
  reply: "Draft",
  action: "reply",
  title: "Topic title",
  categoryId: 1,
  postId: 2,
  plugin_payload: { enabled: true },
};
export const uncategorizedData: UserDraftData = {
  reply: "Draft",
  categoryId: null,
};

export const missingReply: UserDraftData = {};
// @ts-expect-error reply must be a string
export const numericReply: UserDraftData = { reply: 1 };
// @ts-expect-error action must be a string when present
export const numericAction: UserDraftData = { reply: "", action: 1 };
export const nullDataTitle: UserDraftData = { reply: "", title: null };
// @ts-expect-error categoryId must be numeric or null
export const stringCategoryId: UserDraftData = { reply: "", categoryId: "1" };
// @ts-expect-error postId cannot be null
export const nullPostId: UserDraftData = { reply: "", postId: null };

expectTypeOf<
  Omit<UserDraftFields, "typeTestPluginRating">
>().toEqualTypeOf<ExpectedUserDraftFields>();
expectTypeOf<UserDraftFields>().not.toBeAny();
expectTypeOf<UserDraftFields["typeTestPluginRating"]>().toEqualTypeOf<
  number | undefined
>();

const draft = UserDraft.create();

expectTypeOf(draft).toEqualTypeOf<UserDraft>();
expectTypeOf(draft).not.toBeAny();
expectTypeOf(draft).extract<RestModel>().toEqualTypeOf<UserDraft>();
expectTypeOf<
  Pick<UserDraft, keyof ExpectedUserDraftFields>
>().toEqualTypeOf<ExpectedUserDraftFields>();
expectTypeOf(draft.data).toEqualTypeOf<ExpectedUserDraftData>();
expectTypeOf(draft.data).not.toBeAny();
expectTypeOf(draft.typeTestPluginRating).toEqualTypeOf<number | undefined>();
expectTypeOf(draft.typeTestPluginRating).not.toBeAny();

expectTypeOf(draft.titleHtml).toEqualTypeOf<TrustedHTML>();
expectTypeOf(draft.titleHtml).not.toBeAny();
expectTypeOf(draft.editableDraft).toEqualTypeOf<boolean>();
expectTypeOf(draft.userUrl).toEqualTypeOf<string>();
expectTypeOf(draft.postUrl).toEqualTypeOf<string | undefined>();
expectTypeOf(draft.draftType).toEqualTypeOf<string | false>();
expectTypeOf(draft.currentUser).toEqualTypeOf<User | null>();
expectTypeOf(draft.currentUser).not.toBeAny();

expectTypeOf(UserDraft.create({ ...fields })).toEqualTypeOf<UserDraft>();
expectTypeOf(UserDraft.create({})).toEqualTypeOf<UserDraft>();
expectTypeOf(
  UserDraft.create({
    ...fields,
    data: populatedData,
    category,
    currentUser: user,
    typeTestPluginRating: 5,
    undeclaredServerAttribute: { enabled: true },
  })
).toEqualTypeOf<UserDraft>();
expectTypeOf(
  UserDraft.create({
    data: { reply: "Draft", categoryId: null, plugin_payload: [1, 2] },
    topic_id: null,
    name: null,
    title: null,
    archetype: null,
    post_number: null,
    category: null,
    currentUser: null,
  })
).toEqualTypeOf<UserDraft>();
expectTypeOf(
  UserDraft.create({
    topic_id: 1,
    name: "Author",
    title: "Topic title",
    slug: "topic-title",
    category_id: 2,
    closed: true,
    archetype: "regular",
    archived: true,
    truncated: true,
    post_number: 3,
  })
).toEqualTypeOf<UserDraft>();

// @ts-expect-error created_at is the serialized timestamp string
UserDraft.create({ created_at: new Date() });
// @ts-expect-error draft_key must be a string
UserDraft.create({ draft_key: 1 });
// @ts-expect-error sequence must be numeric
UserDraft.create({ sequence: "1" });
// @ts-expect-error draft_username must be a string
UserDraft.create({ draft_username: null });
// @ts-expect-error avatar_template must be a string
UserDraft.create({ avatar_template: 1 });
// @ts-expect-error the stream has already parsed the serialized data
UserDraft.create({ data: '{"reply":"Draft"}' });
expectTypeOf(UserDraft.create({ data: {} })).toEqualTypeOf<UserDraft>();
// @ts-expect-error the data index signature must not loosen declared fields
UserDraft.create({ data: { reply: "Draft", postId: "1" } });
// @ts-expect-error topic_id must be numeric or null
UserDraft.create({ topic_id: "1" });
// @ts-expect-error username must be a string
UserDraft.create({ username: null });
// @ts-expect-error username_lower must be a string
UserDraft.create({ username_lower: 1 });
// @ts-expect-error name must be a string or null when present
UserDraft.create({ name: 1 });
// @ts-expect-error user_id must be numeric
UserDraft.create({ user_id: "1" });
// @ts-expect-error title must be a string or null when present
UserDraft.create({ title: 1 });
// @ts-expect-error slug cannot be null
UserDraft.create({ slug: null });
// @ts-expect-error category_id cannot be null
UserDraft.create({ category_id: null });
// @ts-expect-error closed is omitted rather than serialized as false
UserDraft.create({ closed: false });
// @ts-expect-error archetype must be a string or null
UserDraft.create({ archetype: 1 });
// @ts-expect-error archived is omitted rather than serialized as false
UserDraft.create({ archived: false });
// @ts-expect-error the stream always supplies a string excerpt
UserDraft.create({ excerpt: null });
// @ts-expect-error truncated is omitted rather than serialized as false
UserDraft.create({ truncated: false });
// @ts-expect-error post_number must be numeric or null
UserDraft.create({ post_number: "1" });
// @ts-expect-error category must be a Category instance or null
UserDraft.create({ category: 1 });
// @ts-expect-error currentUser must be a User instance or null
UserDraft.create({ currentUser: "author" });
// @ts-expect-error augmented fields retain their declared type in create attrs
UserDraft.create({ typeTestPluginRating: "5" });

expectTypeOf<ModelFor<"user-draft">>().toEqualTypeOf<UserDraft>();
expectTypeOf<ModelFor<"user-draft">>().not.toBeAny();

const storedDraft = store.createRecord("user-draft");

expectTypeOf(storedDraft).toEqualTypeOf<UserDraft>();
expectTypeOf(storedDraft).not.toBeAny();
expectTypeOf(storedDraft.typeTestPluginRating).toEqualTypeOf<
  number | undefined
>();
expectTypeOf(
  store.createRecord("user-draft", {
    ...fields,
    typeTestPluginRating: 5,
    undeclaredServerAttribute: true,
  })
).toEqualTypeOf<UserDraft>();
// @ts-expect-error the registry preserves declared field types in store attrs
store.createRecord("user-draft", { draft_key: 1 });
// @ts-expect-error the registry preserves literal true fields in store attrs
store.createRecord("user-draft", { closed: false });
// @ts-expect-error the registry preserves augmented field types in store attrs
store.createRecord("user-draft", { typeTestPluginRating: "5" });
