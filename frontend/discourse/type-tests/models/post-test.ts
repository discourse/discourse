import type EmberObject from "@ember/object";
import type { TrustedHTML } from "@ember/template";
import { expectTypeOf } from "expect-type";
import type ActionSummary from "discourse/models/action-summary";
import type {
  CategoryFields,
  default as Category,
} from "discourse/models/category";
import Post, {
  _addTrackedPostProperty,
  clearAddedTrackedPostProperties,
} from "discourse/models/post";
import type RestModel from "discourse/models/rest";
import Topic, { TopicBasicUser } from "discourse/models/topic";
import type User from "discourse/models/user";
import StoreService, { ModelFor } from "discourse/services/store";

declare const store: StoreService;
declare const post: Post;
declare const user: User;

expectTypeOf(post).toExtend<RestModel>();
expectTypeOf<ModelFor<"post">>().toEqualTypeOf<Post>();
expectTypeOf(store.createRecord("post", { id: 1 })).toEqualTypeOf<Post>();
expectTypeOf(store.find("post", 1)).resolves.toEqualTypeOf<Post>();
expectTypeOf(Post.create({ raw: "hi" })).toEqualTypeOf<Post>();
// Creation takes the server's action summaries; `munge` turns them into models.
expectTypeOf(
  Post.create({ actions_summary: [{ id: 2 }] })
).toEqualTypeOf<Post>();
expectTypeOf(
  store.createRecord("post", { actions_summary: [{ id: 2 }] })
).toEqualTypeOf<Post>();
expectTypeOf(
  Post.munge({ actions_summary: [{ id: 2 }] }).actions_summary
).toEqualTypeOf<ActionSummary[] | undefined>();

/* Identity: every server path and the staged composer post supply these. */

expectTypeOf(post.id).toEqualTypeOf<number>();
expectTypeOf(post.post_number).toEqualTypeOf<number>();

/* Search results, nested activity and composer drafts build partial posts, so the rest are optional. */

expectTypeOf(post.topic_id).toEqualTypeOf<number | undefined>();
expectTypeOf(post.topic).toEqualTypeOf<Topic | undefined>();
expectTypeOf(post.cooked).toEqualTypeOf<string | undefined>();
expectTypeOf(post.raw).toEqualTypeOf<string | undefined>();
expectTypeOf(post.post_type).toEqualTypeOf<number | undefined>();
expectTypeOf(post.version).toEqualTypeOf<number | undefined>();
expectTypeOf(post.reply_count).toEqualTypeOf<number | undefined>();
expectTypeOf(post.reply_to_post_number).toEqualTypeOf<
  number | null | undefined
>();
expectTypeOf(post.readers_count).toEqualTypeOf<number | undefined>();
expectTypeOf(post.reads).toEqualTypeOf<number | undefined>();
expectTypeOf(post.quote_count).toEqualTypeOf<number | undefined>();
expectTypeOf(post.incoming_link_count).toEqualTypeOf<number | undefined>();
expectTypeOf(post.score).toEqualTypeOf<number | undefined>();
expectTypeOf(post.post_url).toEqualTypeOf<string | undefined>();
expectTypeOf(post.topic_slug).toEqualTypeOf<string | null | undefined>();
expectTypeOf(post.edit_reason).toEqualTypeOf<string | null | undefined>();

// The stream stages a new post with a Date; deletion writes one too.
expectTypeOf(post.created_at).toEqualTypeOf<string | Date | undefined>();
expectTypeOf(post.updated_at).toEqualTypeOf<string | undefined>();
expectTypeOf(post.deleted_at).toEqualTypeOf<string | Date | null | undefined>();
expectTypeOf(post.deleted_by).toEqualTypeOf<
  TopicBasicUser | User | null | undefined
>();

/* Author fields describe the post's author, not the viewer. */

expectTypeOf(post.user_id).toEqualTypeOf<number | null | undefined>();
expectTypeOf(post.username).toEqualTypeOf<string | null | undefined>();
// Sent only when names are enabled.
expectTypeOf(post.name).toEqualTypeOf<string | null | undefined>();
expectTypeOf(post.display_username).toEqualTypeOf<string | null | undefined>();
expectTypeOf(post.avatar_template).toEqualTypeOf<string | null | undefined>();
expectTypeOf(post.user_title).toEqualTypeOf<string | null | undefined>();
expectTypeOf(post.trust_level).toEqualTypeOf<number | null | undefined>();
expectTypeOf(post.primary_group_name).toEqualTypeOf<
  string | null | undefined
>();
expectTypeOf(post.flair_name).toEqualTypeOf<string | null | undefined>();
expectTypeOf(post.flair_url).toEqualTypeOf<string | null | undefined>();
expectTypeOf(post.flair_bg_color).toEqualTypeOf<string | null | undefined>();
expectTypeOf(post.flair_color).toEqualTypeOf<string | null | undefined>();
expectTypeOf(post.flair_group_id).toEqualTypeOf<number | null | undefined>();
expectTypeOf(post.moderator).toEqualTypeOf<boolean | undefined>();
expectTypeOf(post.admin).toEqualTypeOf<boolean | undefined>();
expectTypeOf(post.staff).toEqualTypeOf<boolean | undefined>();
expectTypeOf(post.title_is_group).toEqualTypeOf<boolean | undefined>();
expectTypeOf(post.user_status).toEqualTypeOf<
  | {
      description: string;
      emoji: string;
      ends_at: string | null;
      message_bus_last_id: number;
    }
  | undefined
>();
expectTypeOf(post.user_custom_fields).toEqualTypeOf<
  Record<string, unknown> | undefined
>();

/* Viewer permissions and state. */

expectTypeOf(post.yours).toEqualTypeOf<boolean | undefined>();
expectTypeOf(post.can_delete).toEqualTypeOf<boolean | undefined>();
expectTypeOf(post.can_recover).toEqualTypeOf<boolean | undefined>();
expectTypeOf(post.can_permanently_delete).toEqualTypeOf<boolean | undefined>();
expectTypeOf(post.can_wiki).toEqualTypeOf<boolean | undefined>();
expectTypeOf(post.can_see_hidden_post).toEqualTypeOf<boolean | undefined>();
expectTypeOf(post.can_view_edit_history).toEqualTypeOf<boolean | undefined>();
expectTypeOf(post.read).toEqualTypeOf<boolean | undefined>();
expectTypeOf(post.hidden).toEqualTypeOf<boolean | undefined>();
expectTypeOf(post.hidden_reason_id).toEqualTypeOf<number | null | undefined>();
// The server sends it only as `true`; expanding a hidden post writes `false`.
expectTypeOf(post.cooked_hidden).toEqualTypeOf<boolean | undefined>();
expectTypeOf(post.user_deleted).toEqualTypeOf<boolean | undefined>();
expectTypeOf(post.wiki).toEqualTypeOf<boolean | undefined>();
expectTypeOf(post.locked).toEqualTypeOf<boolean | undefined>();
expectTypeOf(post.via_email).toEqualTypeOf<boolean | undefined>();
expectTypeOf(post.action_code).toEqualTypeOf<string | undefined>();
expectTypeOf(post.last_wiki_edit).toEqualTypeOf<string | undefined>();
expectTypeOf(post.reviewable_id).toEqualTypeOf<number | null | undefined>();

// `can_edit` is an accessor that plugins can transform; `canEdit` aliases it.
post.can_edit = false;
post.canEdit = true;
expectTypeOf<Post["canEdit"]>().toEqualTypeOf<Post["can_edit"]>();

/* Bookmarks: present only for the viewer's own bookmark; clearing writes null. */

expectTypeOf(post.bookmarked).toEqualTypeOf<boolean | undefined>();
expectTypeOf(post.bookmark_id).toEqualTypeOf<number | null | undefined>();
expectTypeOf(post.bookmark_name).toEqualTypeOf<string | null | undefined>();
expectTypeOf(post.bookmark_reminder_at).toEqualTypeOf<
  string | null | undefined
>();
expectTypeOf(post.bookmark_auto_delete_preference).toEqualTypeOf<
  number | null | undefined
>();

/* Actions: `munge` turns the server entries into ActionSummary models. */

expectTypeOf(post.actions_summary).toEqualTypeOf<ActionSummary[] | undefined>();
expectTypeOf(post.likeAction).toEqualTypeOf<ActionSummary | null | undefined>();
expectTypeOf(post.liked).toEqualTypeOf<boolean>();
expectTypeOf(post.likeCount).toEqualTypeOf<number | undefined>();
expectTypeOf(post.actionsSummary).toEqualTypeOf<
  | {
      id: number;
      postId: number;
      action: string;
      canUndo: boolean | undefined;
      description: string;
    }[]
  | undefined
>();

/* Relationships and nested payloads. */

// `munge` makes a User; the composer and history revert write plain users.
expectTypeOf(post.reply_to_user).not.toBeAny();
post.reply_to_user = null;
post.reply_to_user = { username: "x", avatar_template: "/a/{size}.png" };
post.reply_to_user = user;
post.reply_to_user = {
  id: 1,
  username: "x",
  avatar_template: "/a/{size}.png",
  name: null,
};

expectTypeOf(post.link_counts).toEqualTypeOf<
  | {
      url: string;
      internal: boolean;
      reflection: boolean | null;
      clicks: number;
      title?: string | null;
    }[]
  | undefined
>();
expectTypeOf(post.notice).toEqualTypeOf<
  | { type: "custom"; raw: string; cooked: string; created_by_user_id?: number }
  | { type: "new_user" }
  | { type: "returning_user"; last_posted_at: string }
  | null
  | undefined
>();
expectTypeOf(post.notice_created_by_user).toEqualTypeOf<
  TopicBasicUser | null | undefined
>();
expectTypeOf(post.badges_granted).not.toBeAny();
expectTypeOf(post.mentioned_users).not.toBeAny();

/* Shapes from other endpoints. */

// Latest posts and the user activity feed add titles and an excerpt.
expectTypeOf(post.topic_title).toEqualTypeOf<string | null | undefined>();
expectTypeOf(post.category_id).toEqualTypeOf<number | null | undefined>();
expectTypeOf(post.excerpt).toEqualTypeOf<string | null | undefined>();
expectTypeOf(post.truncated).toEqualTypeOf<boolean | undefined>();
// Latest posts attach the category and a trusted HTML title.
expectTypeOf(post.category).toEqualTypeOf<
  Category | number | null | undefined
>();
expectTypeOf(post.topic_html_title).toEqualTypeOf<
  string | TrustedHTML | null | undefined
>();
// Search results.
expectTypeOf(post.blurb).toEqualTypeOf<string | undefined>();
expectTypeOf(post.like_count).toEqualTypeOf<number | undefined>();
expectTypeOf(post.userPath).toEqualTypeOf<string | undefined>();
expectTypeOf(post.topic_title_headline).toEqualTypeOf<
  string | null | undefined
>();
// Nested replies.
expectTypeOf(post.direct_reply_count).toEqualTypeOf<number | undefined>();
expectTypeOf(post.total_descendant_count).toEqualTypeOf<number | undefined>();
expectTypeOf(post.deleted_post_placeholder).toEqualTypeOf<
  boolean | undefined
>();
expectTypeOf(post.ignored_post_placeholder).toEqualTypeOf<
  boolean | undefined
>();
expectTypeOf(post.avatar_color).toEqualTypeOf<string | null | undefined>();
// Creating or editing a post.
expectTypeOf(post.draft_sequence).toEqualTypeOf<number | undefined>();
// Content localization.
expectTypeOf(post.locale).toEqualTypeOf<string | null | undefined>();
expectTypeOf(post.is_localized).toEqualTypeOf<boolean | undefined>();
expectTypeOf(post.post_localizations_count).toEqualTypeOf<number | undefined>();
expectTypeOf(post.can_localize_post).toEqualTypeOf<boolean | undefined>();

/* Client-only state. */

expectTypeOf(post.customShare).toEqualTypeOf<string | null>();
expectTypeOf(post.staged).toEqualTypeOf<boolean | undefined>();
expectTypeOf(post.hasGap).toEqualTypeOf<boolean | undefined>();
expectTypeOf(post.localizedCooked).toEqualTypeOf<string | null | undefined>();

/* Derived values. */

expectTypeOf(post.new_user).toEqualTypeOf<boolean>();
expectTypeOf(post.firstPost).toEqualTypeOf<boolean>();
expectTypeOf(post.hasReplies).toEqualTypeOf<boolean>();
expectTypeOf(post.isWhisper).toEqualTypeOf<boolean>();
expectTypeOf(post.url).toEqualTypeOf<string>();
expectTypeOf(post.urlWithNumber).toEqualTypeOf<string>();
expectTypeOf(post.usernameUrl).toEqualTypeOf<string>();
expectTypeOf(post.shareUrl).toEqualTypeOf<string>();
expectTypeOf(post.user).toEqualTypeOf<User | null>();
expectTypeOf(post.displayDate).toEqualTypeOf<string | Date | undefined>();

/* Instance methods. */

expectTypeOf(post.updatePostField("wiki", true)).toExtend<Promise<unknown>>();
expectTypeOf(post.recover()).resolves.toEqualTypeOf<void>();
expectTypeOf(post.setDeletedState(user)).resolves.toEqualTypeOf<void>();
post.undoDeleteState();
post.undoDeleteState({ force_destroy: true });
expectTypeOf(post.destroy(user)).toExtend<Promise<unknown>>();
post.destroy(user, { force_destroy: true });
post.updateFromPost(post);
expectTypeOf(post.expandHidden()).resolves.toEqualTypeOf<void>();
expectTypeOf(post.toggleLocalizedContent()).resolves.toEqualTypeOf<void>();
expectTypeOf(post.expand()).resolves.toEqualTypeOf<void>();
post.createBookmark({
  id: 1,
  name: "x",
  reminder_at: null,
  auto_delete_preference: 0,
});
post.deleteBookmark(false);
post.clearBookmark();
post.updateLikeCount(3, 1, "liked");
post.revertToRevision(2);

/* Static helpers. */

Post.updateBookmark(1, true);
Post.destroyBookmark(1);
Post.deleteMany([1, 2]);
Post.deleteMany([1, 2], { agreeWithFirstReplyFlag: false });
Post.mergePosts([1, 2]);
expectTypeOf(Post.loadRevision(1, 2)).resolves.toExtend<EmberObject>();
Post.hideRevision(1, 2);
Post.showRevision(1, 2);
Post.permanentlyDeleteRevisions(1);
Post.loadRawEmail(1);

// An edit that moves the topic sends back the new category with every saved-category field.
expectTypeOf<
  NonNullable<Parameters<Post["afterUpdate"]>[0]["category"]>
>().toEqualTypeOf<CategoryFields>();

/* Plugin field registration. */

expectTypeOf(_addTrackedPostProperty).toEqualTypeOf<
  (propertyKey: string) => void
>();
expectTypeOf(clearAddedTrackedPostProperties).toEqualTypeOf<() => void>();
