import { expectTypeOf } from "expect-type";
import RestModel from "discourse/models/rest";
import type Topic from "discourse/models/topic";
import type UserDraft from "discourse/models/user-draft";
import type {
  default as StoreService,
  ModelCreateAttrsFor,
  ModelFor,
  NormalizeModelName,
} from "discourse/services/store";

/*
 * The store resolves a model class through "model:" + type, and the resolver
 * normalizes that name. These cases come from running ember-resolver's own
 * string helpers over every type name core and the bundled plugins pass to
 * the store, plus edge cases, so the type must match the runtime exactly.
 */
expectTypeOf<NormalizeModelName<"ai-agent">>().toEqualTypeOf<"ai-agent">();
expectTypeOf<
  NormalizeModelName<"ai-decision-model">
>().toEqualTypeOf<"ai-decision-model">();
expectTypeOf<
  NormalizeModelName<"ai-embedding">
>().toEqualTypeOf<"ai-embedding">();
expectTypeOf<NormalizeModelName<"ai-feature">>().toEqualTypeOf<"ai-feature">();
expectTypeOf<NormalizeModelName<"ai-llm">>().toEqualTypeOf<"ai-llm">();
expectTypeOf<
  NormalizeModelName<"ai-mcp-server">
>().toEqualTypeOf<"ai-mcp-server">();
expectTypeOf<NormalizeModelName<"ai-secret">>().toEqualTypeOf<"ai-secret">();
expectTypeOf<NormalizeModelName<"ai-tool">>().toEqualTypeOf<"ai-tool">();
expectTypeOf<NormalizeModelName<"api-key">>().toEqualTypeOf<"api-key">();
expectTypeOf<
  NormalizeModelName<"badge-grouping">
>().toEqualTypeOf<"badge-grouping">();
expectTypeOf<NormalizeModelName<"bookmark">>().toEqualTypeOf<"bookmark">();
expectTypeOf<NormalizeModelName<"category">>().toEqualTypeOf<"category">();
expectTypeOf<NormalizeModelName<"channel">>().toEqualTypeOf<"channel">();
expectTypeOf<NormalizeModelName<"composer">>().toEqualTypeOf<"composer">();
expectTypeOf<
  NormalizeModelName<"composer-message">
>().toEqualTypeOf<"composer-message">();
expectTypeOf<
  NormalizeModelName<"directoryItem">
>().toEqualTypeOf<"directory-item">();
expectTypeOf<
  NormalizeModelName<"discourse-automation-automation">
>().toEqualTypeOf<"discourse-automation-automation">();
expectTypeOf<
  NormalizeModelName<"discourse-automation-scriptable">
>().toEqualTypeOf<"discourse-automation-scriptable">();
expectTypeOf<
  NormalizeModelName<"discourse-workflows-workflow">
>().toEqualTypeOf<"discourse-workflows-workflow">();
expectTypeOf<
  NormalizeModelName<"email-style">
>().toEqualTypeOf<"email-style">();
expectTypeOf<
  NormalizeModelName<"email-template">
>().toEqualTypeOf<"email-template">();
expectTypeOf<
  NormalizeModelName<"embeddable-host">
>().toEqualTypeOf<"embeddable-host">();
expectTypeOf<NormalizeModelName<"embedding">>().toEqualTypeOf<"embedding">();
expectTypeOf<
  NormalizeModelName<"flagged-post">
>().toEqualTypeOf<"flagged-post">();
expectTypeOf<
  NormalizeModelName<"flagged-topic">
>().toEqualTypeOf<"flagged-topic">();
expectTypeOf<NormalizeModelName<"group">>().toEqualTypeOf<"group">();
expectTypeOf<NormalizeModelName<"listTag">>().toEqualTypeOf<"list-tag">();
expectTypeOf<NormalizeModelName<"live-room">>().toEqualTypeOf<"live-room">();
expectTypeOf<NormalizeModelName<"nav-item">>().toEqualTypeOf<"nav-item">();
expectTypeOf<
  NormalizeModelName<"notification">
>().toEqualTypeOf<"notification">();
expectTypeOf<
  NormalizeModelName<"pending-post">
>().toEqualTypeOf<"pending-post">();
expectTypeOf<NormalizeModelName<"permalink">>().toEqualTypeOf<"permalink">();
expectTypeOf<NormalizeModelName<"plugin">>().toEqualTypeOf<"plugin">();
expectTypeOf<NormalizeModelName<"post">>().toEqualTypeOf<"post">();
expectTypeOf<
  NormalizeModelName<"post-reader">
>().toEqualTypeOf<"post-reader">();
expectTypeOf<NormalizeModelName<"post-reply">>().toEqualTypeOf<"post-reply">();
expectTypeOf<
  NormalizeModelName<"post-reply-history">
>().toEqualTypeOf<"post-reply-history">();
expectTypeOf<NormalizeModelName<"postStream">>().toEqualTypeOf<"post-stream">();
expectTypeOf<
  NormalizeModelName<"published-page">
>().toEqualTypeOf<"published-page">();
expectTypeOf<
  NormalizeModelName<"published_page">
>().toEqualTypeOf<"published-page">();
expectTypeOf<NormalizeModelName<"query">>().toEqualTypeOf<"query">();
expectTypeOf<NormalizeModelName<"reviewable">>().toEqualTypeOf<"reviewable">();
expectTypeOf<
  NormalizeModelName<"reviewable-claimed-topic">
>().toEqualTypeOf<"reviewable-claimed-topic">();
expectTypeOf<
  NormalizeModelName<"reviewable-explanation">
>().toEqualTypeOf<"reviewable-explanation">();
expectTypeOf<
  NormalizeModelName<"reviewable-settings">
>().toEqualTypeOf<"reviewable-settings">();
expectTypeOf<
  NormalizeModelName<"reviewable-topic">
>().toEqualTypeOf<"reviewable-topic">();
expectTypeOf<NormalizeModelName<"rule">>().toEqualTypeOf<"rule">();
expectTypeOf<
  NormalizeModelName<"similar-topic">
>().toEqualTypeOf<"similar-topic">();
expectTypeOf<NormalizeModelName<"site">>().toEqualTypeOf<"site">();
expectTypeOf<NormalizeModelName<"site-text">>().toEqualTypeOf<"site-text">();
expectTypeOf<
  NormalizeModelName<"staff-action-log">
>().toEqualTypeOf<"staff-action-log">();
expectTypeOf<NormalizeModelName<"tag">>().toEqualTypeOf<"tag">();
expectTypeOf<NormalizeModelName<"tag-info">>().toEqualTypeOf<"tag-info">();
expectTypeOf<
  NormalizeModelName<"tag-settings">
>().toEqualTypeOf<"tag-settings">();
expectTypeOf<NormalizeModelName<"tagGroup">>().toEqualTypeOf<"tag-group">();
expectTypeOf<
  NormalizeModelName<"tagNotification">
>().toEqualTypeOf<"tag-notification">();
expectTypeOf<NormalizeModelName<"theme">>().toEqualTypeOf<"theme">();
expectTypeOf<
  NormalizeModelName<"tl3Requirements">
>().toEqualTypeOf<"tl3-requirements">();
expectTypeOf<NormalizeModelName<"topic">>().toEqualTypeOf<"topic">();
expectTypeOf<
  NormalizeModelName<"topicDetails">
>().toEqualTypeOf<"topic-details">();
expectTypeOf<NormalizeModelName<"topicList">>().toEqualTypeOf<"topic-list">();
expectTypeOf<NormalizeModelName<"user">>().toEqualTypeOf<"user">();
expectTypeOf<NormalizeModelName<"user-field">>().toEqualTypeOf<"user-field">();
expectTypeOf<NormalizeModelName<"user-note">>().toEqualTypeOf<"user-note">();
expectTypeOf<NormalizeModelName<"web-hook">>().toEqualTypeOf<"web-hook">();
expectTypeOf<
  NormalizeModelName<"web-hook-event">
>().toEqualTypeOf<"web-hook-event">();
expectTypeOf<NormalizeModelName<"APIKey">>().toEqualTypeOf<"apikey">();
expectTypeOf<NormalizeModelName<"postIDs">>().toEqualTypeOf<"post-ids">();
expectTypeOf<NormalizeModelName<"a.B">>().toEqualTypeOf<"a/b">();
expectTypeOf<NormalizeModelName<"_Foo">>().toEqualTypeOf<"-foo">();
expectTypeOf<NormalizeModelName<"Topic">>().toEqualTypeOf<"topic">();
expectTypeOf<
  NormalizeModelName<"user_API_key">
>().toEqualTypeOf<"user-api-key">();
expectTypeOf<NormalizeModelName<"foo bar">>().toEqualTypeOf<"foo-bar">();
expectTypeOf<NormalizeModelName<"x2Y">>().toEqualTypeOf<"x2-y">();
expectTypeOf<
  NormalizeModelName<"already-dashed">
>().toEqualTypeOf<"already-dashed">();
expectTypeOf<NormalizeModelName<"ABC">>().toEqualTypeOf<"abc">();
expectTypeOf<NormalizeModelName<"aBC">>().toEqualTypeOf<"a-bc">();
expectTypeOf<
  NormalizeModelName<"post.reply.history">
>().toEqualTypeOf<"post/reply/history">();
expectTypeOf<NormalizeModelName<"a__b">>().toEqualTypeOf<"a--b">();
expectTypeOf<
  NormalizeModelName<"camelCaseKey">
>().toEqualTypeOf<"camel-case-key">();

class NameTestCamel extends RestModel {
  declare camelField: string;
}

class NameTestDashed extends RestModel {
  declare dashedField: number;
}

class NameTestCollideA extends RestModel {
  declare collideA: true;
}

class NameTestCollideB extends RestModel {
  declare collideB: true;
}

declare module "discourse/services/store" {
  interface ModelRegistry {
    // registered camelCase, as some callers spell it
    nameTestCamel: NameTestCamel;
    // registered dasherized
    "name-test-dashed": NameTestDashed;
    // two spellings of one runtime name
    nameTestCollide: NameTestCollideA;
    "name-test-collide": NameTestCollideB;
  }

  interface ModelCreateAttrsRegistry {
    nameTestCamel: { camelField?: string | number };
  }
}

declare const store: StoreService;
declare const dynamicType: string;

// A camelCase registration is found by every spelling that resolves to it.
expectTypeOf<ModelFor<"nameTestCamel">>().toEqualTypeOf<NameTestCamel>();
expectTypeOf<ModelFor<"name-test-camel">>().toEqualTypeOf<NameTestCamel>();
expectTypeOf<ModelFor<"name_test_camel">>().toEqualTypeOf<NameTestCamel>();

// A dasherized registration is found by camelCase and underscored lookups.
expectTypeOf<ModelFor<"name-test-dashed">>().toEqualTypeOf<NameTestDashed>();
expectTypeOf<ModelFor<"nameTestDashed">>().toEqualTypeOf<NameTestDashed>();
expectTypeOf<ModelFor<"name_test_dashed">>().toEqualTypeOf<NameTestDashed>();

// Two registrations of the same runtime name surface as a union.
expectTypeOf<ModelFor<"name-test-collide">>().toEqualTypeOf<
  NameTestCollideA | NameTestCollideB
>();
expectTypeOf<ModelFor<"nameTestCollide">>().toEqualTypeOf<
  NameTestCollideA | NameTestCollideB
>();

// Core registrations resolve through other spellings too.
expectTypeOf<ModelFor<"user_draft">>().toEqualTypeOf<UserDraft>();
expectTypeOf<ModelFor<"userDraft">>().toEqualTypeOf<UserDraft>();
expectTypeOf<ModelFor<"Topic">>().toEqualTypeOf<Topic>();

// Anything not provably registered falls back to the base model.
expectTypeOf<ModelFor<string>>().toEqualTypeOf<RestModel>();
expectTypeOf<ModelFor<`name-test-${string}`>>().toEqualTypeOf<RestModel>();
expectTypeOf<ModelFor<"name-test-unregistered">>().toEqualTypeOf<RestModel>();
expectTypeOf<ModelFor<"nameTestCamelX">>().toEqualTypeOf<RestModel>();

// A union of names gives the union of their models.
expectTypeOf<ModelFor<"nameTestCamel" | "name-test-dashed">>().toEqualTypeOf<
  NameTestCamel | NameTestDashed
>();

// Creation attributes follow the same normalization.
expectTypeOf<ModelCreateAttrsFor<"name-test-camel">>().toEqualTypeOf<{
  camelField?: string | number;
}>();

// The store methods pick the model up through any spelling.
expectTypeOf(
  store.createRecord("name-test-camel")
).toEqualTypeOf<NameTestCamel>();
expectTypeOf(
  store.createRecord("name_test_camel", { camelField: 1 })
).toEqualTypeOf<NameTestCamel>();
// @ts-expect-error the registered creation attributes are still checked
store.createRecord("name-test-camel", { camelField: true });
expectTypeOf(
  store.find("nameTestDashed", 1)
).resolves.toEqualTypeOf<NameTestDashed>();
expectTypeOf(store.createRecord(dynamicType)).toEqualTypeOf<RestModel>();

/* More cases generated with the installed resolver's string helpers. */
type NormalizationCases = [
  ["", ""],
  ["aBaB", "a-ba-b"],
  ["a_ B", "a--b"],
  ["foo\tBar\nBaz", "foo\tbar\nbaz"],
  ["éX", "éx"],
  ["aÉ", "aé"],
  ["İTest", "i̇test"],
  ["ΟΣ", "ος"],
  ["under_score.path Name", "under-score/path-name"],
  ["foo:bar:baz", "foo"],
  [
    "aBcDeFgHiJaBcDeFgHiJaBcDeFgHiJaBcDeFgHiJaBcDeFgHiJaBcDeFgHiJ",
    "a-bc-de-fg-hi-ja-bc-de-fg-hi-ja-bc-de-fg-hi-ja-bc-de-fg-hi-ja-bc-de-fg-hi-ja-bc-de-fg-hi-j",
  ],
];

expectTypeOf<{
  [K in NormalizationCases[number] as K[0]]: NormalizeModelName<K[0]>;
}>().toEqualTypeOf<{
  [K in NormalizationCases[number] as K[0]]: K[1];
}>();

declare module "discourse/services/store" {
  interface ModelRegistry {
    extra_under_score: UserDraft;
    "extra.path Name": Topic;
  }

  interface ModelCreateAttrsRegistry {
    extra_under_score: { source?: "underscore" };
    extraUnderScore: { source?: "camel" };
  }
}

expectTypeOf<ModelFor<"extraUnderScore">>().toEqualTypeOf<UserDraft>();
expectTypeOf<ModelFor<"extra/path-name">>().toEqualTypeOf<Topic>();
expectTypeOf<ModelCreateAttrsFor<"extra-under-score">>().toEqualTypeOf<
  { source?: "underscore" } | { source?: "camel" }
>();
expectTypeOf<ModelCreateAttrsFor<"extraUnderScore">>().toEqualTypeOf<
  { source?: "underscore" } | { source?: "camel" }
>();
expectTypeOf<ModelCreateAttrsFor<"extra_under_score">>().toEqualTypeOf<
  { source?: "underscore" } | { source?: "camel" }
>();
expectTypeOf<ModelCreateAttrsFor<"userDraft">>().toEqualTypeOf<
  ModelCreateAttrsFor<"user-draft">
>();
expectTypeOf<
  ModelCreateAttrsFor<"extra/path-name" | "extra-under-score">
>().toEqualTypeOf<
  | ModelCreateAttrsFor<"extra.path Name">
  | { source?: "underscore" }
  | { source?: "camel" }
>();

expectTypeOf<NormalizeModelName<string>>().toEqualTypeOf<string>();
expectTypeOf<NormalizeModelName<`topic${string}`>>().toEqualTypeOf<string>();
expectTypeOf<NormalizeModelName<`topic${number}`>>().toEqualTypeOf<string>();
expectTypeOf<NormalizeModelName<Uppercase<string>>>().toEqualTypeOf<string>();
expectTypeOf<NormalizeModelName<"userDraft" | "Topic">>().toEqualTypeOf<
  "user-draft" | "topic"
>();
expectTypeOf<NormalizeModelName<never>>().toBeNever();
expectTypeOf<ModelFor<never>>().toBeNever();
expectTypeOf<ModelFor<`topic${string}`>>().toEqualTypeOf<RestModel>();
expectTypeOf<ModelFor<`${string}topic`>>().toEqualTypeOf<RestModel>();
expectTypeOf<ModelFor<`to${string}pic`>>().toEqualTypeOf<RestModel>();
expectTypeOf<ModelFor<`topic${number}`>>().toEqualTypeOf<RestModel>();
expectTypeOf<ModelFor<`topic:${string}`>>().toEqualTypeOf<RestModel>();
expectTypeOf<ModelFor<Uppercase<string>>>().toEqualTypeOf<RestModel>();
expectTypeOf<ModelCreateAttrsFor<string>>().toEqualTypeOf<
  ModelCreateAttrsFor<"extra-unregistered">
>();
