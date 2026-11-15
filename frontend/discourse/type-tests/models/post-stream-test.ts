import { expectTypeOf } from "expect-type";
import type Post from "discourse/models/post";
import PostStream, {
  Placeholder,
  type PostStreamData,
  resetLastEditNotificationClick,
  setLastEditNotificationClick,
} from "discourse/models/post-stream";
import Posts from "discourse/models/posts";
import type RestModel from "discourse/models/rest";
import type Topic from "discourse/models/topic";
import type User from "discourse/models/user";
import StoreService, { ModelFor } from "discourse/services/store";

declare const store: StoreService;
declare const stream: PostStream;
declare const post: Post;
declare const user: User;
declare const topic: Topic;
declare const maybePost: Post | null | undefined;

expectTypeOf(stream).toExtend<RestModel>();
expectTypeOf<ModelFor<"post-stream">>().toEqualTypeOf<PostStream>();
// Topic creates its stream under the camelCase key.
expectTypeOf<ModelFor<"postStream">>().toEqualTypeOf<PostStream>();
expectTypeOf(topic.postStream).toEqualTypeOf<PostStream>();
expectTypeOf(
  store.createRecord("postStream", { id: 1, topic })
).toEqualTypeOf<PostStream>();

/* State hydrated from the topic view's `post_stream`. */

expectTypeOf(stream.topic).toEqualTypeOf<Topic>();
expectTypeOf(stream.posts).toEqualTypeOf<Post[]>();
expectTypeOf(stream.stream).toEqualTypeOf<number[]>();
expectTypeOf(stream.userFilters).toEqualTypeOf<string[]>();
// Gap maps are keyed by the post the hidden ids sit before or after.
expectTypeOf(stream.gaps).toEqualTypeOf<
  | { before: Record<number, number[]>; after: Record<number, number[]> }
  | null
  | undefined
>();
// Mega topics send `isMegaTopic` and `lastId` instead of the full stream.
expectTypeOf(stream.isMegaTopic).toEqualTypeOf<boolean | undefined>();
// `lastId` is null when the filtered stream is empty.
expectTypeOf(stream.lastId).toEqualTypeOf<number | null | undefined>();
// `[stream position, days ago]` pairs; mega topics omit them.
expectTypeOf(stream.timelineLookup).toEqualTypeOf<
  [number, number][] | undefined
>();

/* Client state. */

expectTypeOf(stream.filter).toEqualTypeOf<string | null | undefined>();
expectTypeOf(stream.filterRepliesToPostNumber).toEqualTypeOf<number | false>();
expectTypeOf(stream.filterUpwardsPostID).toEqualTypeOf<number | false>();
expectTypeOf(stream.focusTarget).toEqualTypeOf<{
  postNumber: number;
  done: boolean;
} | null>();
expectTypeOf(stream.appendingPlaceholders).toEqualTypeOf<number>();
expectTypeOf(stream.loaded).toEqualTypeOf<boolean>();
expectTypeOf(stream.loadingAbove).toEqualTypeOf<boolean>();
expectTypeOf(stream.loadingBelow).toEqualTypeOf<boolean>();
expectTypeOf(stream.loadingFilter).toEqualTypeOf<boolean>();
expectTypeOf(stream.loadingLastPost).toEqualTypeOf<boolean>();
expectTypeOf(stream.stagingPost).toEqualTypeOf<boolean>();
expectTypeOf(stream.loadingNearPost).toEqualTypeOf<number | null | undefined>();
expectTypeOf(stream.lastAppended).toEqualTypeOf<Post | undefined>();

/* Derived state. */

expectTypeOf(stream.loading).toEqualTypeOf<boolean>();
expectTypeOf(stream.notLoading).toEqualTypeOf<boolean>();
expectTypeOf(stream.hasPosts).toEqualTypeOf<boolean>();
expectTypeOf(stream.hasLoadedData).toEqualTypeOf<boolean>();
expectTypeOf(stream.firstPostPresent).toEqualTypeOf<boolean>();
expectTypeOf(stream.loadedAllPosts).toEqualTypeOf<boolean>();
expectTypeOf(stream.canAppendMore).toEqualTypeOf<boolean>();
expectTypeOf(stream.canPrependMore).toEqualTypeOf<boolean>();
expectTypeOf(stream.summary).toEqualTypeOf<boolean>();
expectTypeOf(stream.firstPostId).toEqualTypeOf<number | undefined>();
expectTypeOf(stream.lastPostId).toEqualTypeOf<number | null | undefined>();
expectTypeOf(stream.previousWindow).toEqualTypeOf<number[]>();
expectTypeOf(stream.nextWindow).toEqualTypeOf<number[]>();
expectTypeOf(stream.loadedPosts).toEqualTypeOf<Post[]>();
expectTypeOf(stream.postsWithPlaceholders).toEqualTypeOf<
  (Post | Placeholder)[]
>();
expectTypeOf(stream.streamFilters).toExtend<{
  filter?: string;
  username_filters?: string;
  replies_to_post_number?: number;
  filter_upwards_post_id?: number;
}>();
expectTypeOf(PostStream.PLACEHOLDER).toEqualTypeOf<Placeholder>();
expectTypeOf(PostStream.PLACEHOLDER.viewName).toEqualTypeOf<string>();

/* Lookups. */

// Callers pass ids read from the DOM and nullable controller state.
stream.findLoadedPost("12");
stream.findLoadedPost(null);
stream.findLoadedPost(undefined);
stream.loadPost("12");
stream.closestPostForPostNumber("3");

// The identity map clears the staged post's slot with null.
expectTypeOf(stream.findLoadedPost(1)).toEqualTypeOf<Post | null | undefined>();
expectTypeOf(stream.postForPostNumber(1)).toEqualTypeOf<Post | undefined>();
expectTypeOf(stream.closestPostForPostNumber(1)).toEqualTypeOf<
  Post | null | undefined
>();
expectTypeOf(stream.closestPostNumberFor(1)).toEqualTypeOf<
  number | null | undefined
>();
expectTypeOf(stream.findPostIdForPostNumber(1)).toEqualTypeOf<
  number | undefined
>();
expectTypeOf(stream.progressIndexOfPost(post)).toEqualTypeOf<number>();
expectTypeOf(stream.indexOf(post)).toEqualTypeOf<number>();
expectTypeOf(stream.closestDaysAgoFor(1)).toEqualTypeOf<number | undefined>();

/* Loading. */

// `createRecord` always yields a post, so storing it does too.
expectTypeOf(stream.loadPost(1)).resolves.toEqualTypeOf<Post>();
expectTypeOf(stream.loadPostByPostNumber(1)).resolves.toEqualTypeOf<Post>();
expectTypeOf(
  stream.loadNearestPostToDate("2026-10-27")
).resolves.toEqualTypeOf<Post>();
expectTypeOf(stream.findPostsByIds([1, 2])).resolves.toEqualTypeOf<Post[]>();
stream.findPostsByIds([1, 2], { background: true });
expectTypeOf(stream.storePost(post)).toEqualTypeOf<Post>();
expectTypeOf(stream.storePost(undefined)).toEqualTypeOf<undefined>();
expectTypeOf(stream.storePost(maybePost)).toEqualTypeOf<Post | undefined>();
expectTypeOf(
  stream.findPostsByIds(["12", null, undefined])
).resolves.toEqualTypeOf<Post[]>();
// The window callback runs with the stream as its receiver.
stream.fetchNextWindow(1, false, function (loaded) {
  expectTypeOf(this).toEqualTypeOf<PostStream>();
  expectTypeOf(loaded).toEqualTypeOf<Post>();
});
expectTypeOf(stream.refresh()).resolves.toEqualTypeOf<void>();
stream.refresh({ nearPost: 3, forceLoad: true, refreshInPlace: true });
stream.refresh({ nearPost: "3", cancelFilter: true });
expectTypeOf(stream.appendMore()).resolves.toEqualTypeOf<Post[] | undefined>();
stream.prependMore({ beforePrepend: () => {} });
stream.fillGapBefore(post, [1, 2]);
stream.fillGapAfter(post, [1, 2]);
expectTypeOf(stream.excerpt(3)).resolves.toEqualTypeOf<
  | {
      post_id: number;
      username: string | null;
      excerpt: string;
      action_code?: string;
      created_at?: string;
    }
  | ""
  | undefined
>();

/* Staging and message-bus updates. */

expectTypeOf(stream.stagePost(post, user)).toEqualTypeOf<
  "alreadyStaging" | "staged" | "offScreen"
>();
stream.commitPost(post);
stream.undoPost(post);
expectTypeOf(stream.appendPost(post)).toEqualTypeOf<Post>();
expectTypeOf(stream.prependPost(post)).toEqualTypeOf<Post>();
stream.removePosts([post]);
stream.removeAllPosts();
stream.triggerNewPostsInStream([1, 2]);
stream.triggerNewPostsInStream([1, 2], { background: true });
stream.triggerRecoveredPost(1);
stream.triggerDeletedPost(1);
stream.triggerDestroyedPost(1);
stream.triggerChangedPost(1, "2026-10-27T10:00:00Z");
stream.triggerChangedPost(1, "2026-10-27T10:00:00Z", { preserveCooked: true });
stream.refreshPost(1, { preserveCooked: true });
stream.triggerLikedPost(1, 3, 2, "liked");
stream.triggerReadPost(1, 4);
expectTypeOf(
  stream.triggerChangedTopicStats()
).resolves.toEqualTypeOf<number>();

/* Filters. */

stream.cancelFilter();
stream.showTopReplies();
stream.filterParticipant("sam");
stream.filterReplies(3, 12);
stream.filterUpwards(12);
stream.focusPostOnRender(3);
stream.highlightQuoteOnRender(3, "quoted text");
expectTypeOf(stream.quoteHighlights).toEqualTypeOf<
  Map<number, { quote: string; revealed: boolean }>
>();
stream.updateFromJson({ posts: [], stream: [1, 2] });
stream.updateFromJson(undefined);
// Nested replies and mega topics hydrate reduced posts, a null lastId and no gaps.
const reduced: PostStreamData = {
  posts: [{ id: 1, post_number: 1, mentioned_users: [] }],
  isMegaTopic: true,
  lastId: null,
  gaps: null,
};
stream.updateFromJson(reduced);
// Route params pass through to the topic view request.
stream.refresh({ nearPost: "3", track_visit: true });

/* Module helpers. */

expectTypeOf(setLastEditNotificationClick).toEqualTypeOf<
  (topicId: number, postNumber: number, revisionNumber: number) => void
>();
expectTypeOf(resetLastEditNotificationClick).toEqualTypeOf<() => void>();

/* Posts: the latest-posts list. */

expectTypeOf(Posts.find()).resolves.toEqualTypeOf<Post[]>();
Posts.find({ before: 10 });
