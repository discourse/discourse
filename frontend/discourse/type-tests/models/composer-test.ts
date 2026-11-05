import EmberObject from "@ember/object";
import { expectTypeOf } from "expect-type";
import type Category from "discourse/models/category";
import Composer, {
  type ComposerImageSizes,
  type ComposerOpenOptions,
  type ComposerSaveOptions,
  CREATE_TOPIC,
  EDIT,
  NEW_TOPIC_KEY,
  PRIVATE_MESSAGE,
  registerCustomizationCallback,
  REPLY,
} from "discourse/models/composer";
import type Post from "discourse/models/post";
import type RestModel from "discourse/models/rest";
import type Site from "discourse/models/site";
import type Topic from "discourse/models/topic";
import type User from "discourse/models/user";
import type UserDraft from "discourse/models/user-draft";
import type UserDraftsStream from "discourse/models/user-drafts-stream";
import type {
  default as StoreService,
  ModelCreateAttrsFor,
  ModelFor,
} from "discourse/services/store";

declare const store: StoreService;
declare const composer: Composer;
declare const topic: Topic;
declare const post: Post;
declare const site: Site;
declare const draft: UserDraft;
declare const stream: UserDraftsStream;
declare const dynamicField: string;

expectTypeOf(composer).toExtend<RestModel>();
expectTypeOf(composer).not.toBeAny();
expectTypeOf<ModelFor<"composer">>().toEqualTypeOf<Composer>();
expectTypeOf(store.createRecord("composer")).toEqualTypeOf<Composer>();
expectTypeOf(
  store.createRecord("composer", {
    action: Composer.CREATE_TOPIC,
    composeState: Composer.OPEN,
  })
).toEqualTypeOf<Composer>();

/* Actions, states and draft keys. */

expectTypeOf(CREATE_TOPIC).toEqualTypeOf<"createTopic">();
expectTypeOf(PRIVATE_MESSAGE).toEqualTypeOf<"privateMessage">();
expectTypeOf(NEW_TOPIC_KEY).toEqualTypeOf<"new_topic">();
expectTypeOf(Composer.REPLY).toEqualTypeOf<"reply">();
expectTypeOf(Composer.ADD_TRANSLATION).toEqualTypeOf<"add_translation">();
expectTypeOf(Composer.FULLSCREEN).toEqualTypeOf<"fullscreen">();
expectTypeOf(composer.composeState).toEqualTypeOf<
  "closed" | "saving" | "open" | "draft" | "fullscreen" | undefined
>();
composer.composeState = Composer.DRAFT;
// Plugins open the composer with their own actions.
expectTypeOf(composer.action).toEqualTypeOf<string | undefined>();
composer.action = REPLY;

/* State. */

expectTypeOf(composer.topic).toEqualTypeOf<Topic | null | undefined>();
expectTypeOf(composer.post).toEqualTypeOf<Post | null | undefined>();
// Clearing the composer resets the reply to null.
expectTypeOf(composer.reply).toEqualTypeOf<string | null | undefined>();
expectTypeOf(composer.title).toEqualTypeOf<string | null | undefined>();
expectTypeOf(composer.draftKey).toEqualTypeOf<string | undefined>();
// Opening a new message supplies no sequence.
expectTypeOf(composer.draftSequence).toEqualTypeOf<number | undefined>();
expectTypeOf(composer.targetRecipients).toEqualTypeOf<string | undefined>();
expectTypeOf(composer.reply_to_post_number).toEqualTypeOf<number | null>();
expectTypeOf(composer.reply_to_user).toEqualTypeOf<{
  id?: number;
  username: string;
  name?: string | null;
  avatar_template: string;
} | null>();
expectTypeOf(composer.categoryId).toEqualTypeOf<number | null>();
composer.categoryId = 3;
composer.categoryId = null;
expectTypeOf(composer.category).toEqualTypeOf<Category | null | undefined>();
// Defaults to the current user, which is null for anonymous sessions.
expectTypeOf(composer.user).toEqualTypeOf<User | null>();
expectTypeOf(composer.unlistTopic).toEqualTypeOf<boolean>();
expectTypeOf(composer.draftSaving).toEqualTypeOf<boolean>();
// Composer and drafts carry tag names; an edit's topic may carry tag records.
composer.tags = ["support"];
composer.tags = [{ id: 1, name: "support", slug: "support" }];

/* Derived state. */

expectTypeOf(composer.creatingTopic).toEqualTypeOf<boolean>();
expectTypeOf(composer.creatingPrivateMessage).toEqualTypeOf<boolean>();
expectTypeOf(composer.editingPost).toEqualTypeOf<boolean>();
expectTypeOf(composer.viewOpen).toEqualTypeOf<boolean>();
expectTypeOf(composer.replyDirty).toEqualTypeOf<boolean>();
expectTypeOf(composer.canSaveDraft).toEqualTypeOf<boolean>();
expectTypeOf(composer.replyLength).toEqualTypeOf<number>();
expectTypeOf(composer.titleLength).toEqualTypeOf<number>();
expectTypeOf(composer.missingReplyCharacters).toEqualTypeOf<number>();
expectTypeOf(composer.composerTime).toEqualTypeOf<number>();
expectTypeOf(composer.composerVersion).toEqualTypeOf<1 | 2>();
expectTypeOf(composer.targetRecipientsArray).toEqualTypeOf<
  { type: "group" | "email" | "user"; name: string }[]
>();

/* Opening. */

composer.open({
  action: CREATE_TOPIC,
  draftKey: NEW_TOPIC_KEY,
  draftSequence: 0,
  topicCategoryId: 3,
  tags: ["support"],
  metaData: null,
});
composer.open({
  action: REPLY,
  draftKey: "topic_1",
  draftSequence: 2,
  topic,
  post,
  quote: "> quoted",
});
composer.open({ action: EDIT, draftKey: "topic_1_post_2", post });
// New messages omit the sequence; drafts restore plugin-registered fields by name.
composer.open({
  action: PRIVATE_MESSAGE,
  draftKey: "new_private_message",
  recipients: "sam,staff",
  archetypeId: "private_message",
  reply_to_user: null,
  ai_agent_id: 3,
});

/* Editing the reply. */

expectTypeOf(
  composer.appendText("text", null, { new_line: true })
).toEqualTypeOf<number>();
composer.appendText("text", 4, { block: true });
expectTypeOf(
  composer.prependText("text", { new_line: true })
).toEqualTypeOf<void>();
composer.setReplyTo(null, null);
composer.setReplyTo(3, { username: "sam", avatar_template: "/a/{size}.png" });
expectTypeOf(composer.getCookedHtml()).toEqualTypeOf<string>();

/* Saving. */

composer.save({
  imageSizes: { "/uploads/a.png": { width: 10, height: 20 } },
  editReason: "typo",
});
composer.saveDraft();
expectTypeOf(composer.serializeDraftData()).toExtend<Record<string, unknown>>();

/* Extension points. */

Composer.serializeOnCreate("ai_agent_id", "aiAgentId");
Composer.serializeToDraft("event_data");
Composer.serializeToTopic("custom_field");
Composer.serializeOnUpdate("custom_field", "customField");
expectTypeOf(Composer.serializedFieldsForCreate()).toEqualTypeOf<string[]>();
expectTypeOf(
  Composer.isEditDraft({ action: "edit", postId: 2 })
).toEqualTypeOf<boolean>();
Composer.isEditDraft(undefined);
registerCustomizationCallback({
  saveLabel(model) {
    expectTypeOf(model).toEqualTypeOf<Composer>();
    return model.creatingTopic ? "composer.create_event" : null;
  },
});
composer.customizationFor("saveIcon");

/* Drafts stream. */

expectTypeOf(stream.content).toEqualTypeOf<UserDraft[] | null>();
expectTypeOf(stream.limit).toEqualTypeOf<number>();
expectTypeOf(stream.hasMore).toEqualTypeOf<boolean>();
expectTypeOf(stream.loading).toEqualTypeOf<boolean>();
expectTypeOf(stream.noContent).toEqualTypeOf<boolean>();
stream.reset();
stream.remove(draft);
stream.findItems();
stream.findItems(site);
expectTypeOf(stream.user).toEqualTypeOf<User | undefined>();

/* Factories and subclasses. */

expectTypeOf(Composer.create()).toEqualTypeOf<Composer>();
expectTypeOf<ModelCreateAttrsFor<"composer">>().toExtend<{
  action?: string;
  composeState?: Composer["composeState"];
}>();
expectTypeOf<Composer["save"]>().toExtend<RestModel["save"]>();
class ExtendedComposer extends Composer {
  override open(options?: ComposerOpenOptions | null) {
    return super.open(options);
  }

  override beforeSave() {
    return super.beforeSave();
  }
}
expectTypeOf(ExtendedComposer.create()).toEqualTypeOf<ExtendedComposer>();

/* Draft restoration and dynamic serializer names. */

composer.open({
  postId: 2,
  original_text: "draft baseline",
  original_title: null,
  original_tags: ["support"],
  plugin_draft_data: { future: true },
});
Composer.serializeOnCreate(dynamicField, "plugin.create.value");
Composer.serializeToDraft(dynamicField, "plugin.draft.value");
Composer.serializeOnUpdate(dynamicField);
Composer.serializeToTopic(dynamicField, "plugin.topic.value");
expectTypeOf(
  composer.serialize({ [dynamicField]: "plugin.value" })
).toEqualTypeOf<Record<string, unknown>>();
expectTypeOf(composer.serialize({ raw: "reply" }, post)).toEqualTypeOf<Post>();
expectTypeOf(composer.cantSubmitPost).toEqualTypeOf<boolean | "" | undefined>();
expectTypeOf(composer.messageBus.clientId).toEqualTypeOf<string>();

/* Posts carry the composer's image sizes and metadata. */

expectTypeOf<Post["imageSizes"]>().toEqualTypeOf<
  Record<string, { width: number; height: number }> | undefined
>();
expectTypeOf<ComposerSaveOptions["imageSizes"]>().toEqualTypeOf<
  ComposerImageSizes | undefined
>();
post.metaData = { custom_field: { nested: true } };
post.metaData = EmberObject.create();
post.metaData = null;
