import { cached, tracked } from "@glimmer/tracking";
import { get } from "@ember/object";
import { dependentKeyCompat } from "@ember/object/compat";
import { trackedMap, trackedObject } from "@ember/reactive/collections";
import { schedule } from "@ember/runloop";
import { service } from "@ember/service";
import { isEmpty } from "@ember/utils";
import { Promise } from "rsvp";
import { ajax } from "discourse/lib/ajax";
import {
  removeValueFromArray,
  removeValuesFromArray,
} from "discourse/lib/array-tools";
import deprecated from "discourse/lib/deprecated";
import { deepMerge } from "discourse/lib/object";
import { autoTrackedArray } from "discourse/lib/tracked-tools";
import { applyBehaviorTransformer } from "discourse/lib/transformer";
import DiscourseURL from "discourse/lib/url";
import type { default as Post, PostCreateAttrs } from "discourse/models/post";
import RestModel, { type RestPayload } from "discourse/models/rest";
import { type default as Topic, loadTopicView } from "discourse/models/topic";
import type User from "discourse/models/user";
import type AppEventsService from "discourse/services/app-events";
import type StoreService from "discourse/services/store";
import { i18n } from "discourse-i18n";

/** Query parameters shared by topic-view and post-window requests. */
export interface PostStreamFilters {
  filter?: string;
  username_filters?: string;
  replies_to_post_number?: number;
  filter_upwards_post_id?: number;
  mixedHiddenPosts?: boolean;
}

/** Refresh mutates nearPost to its parsed numeric value and consumes cancelFilter. */
export type PostStreamRefreshOptions = PostStreamFilters & {
  nearPost?: number | string;
  cancelFilter?: boolean;
  forceLoad?: boolean;
  refreshInPlace?: boolean;
  [key: string]: unknown;
};

/** Topic-view stream attributes; posts are consumed and deleted during hydration. */
export interface PostStreamData {
  posts: PostPayload[];
  stream?: number[];
  gaps?: {
    before: Record<number, number[]>;
    after: Record<number, number[]>;
  } | null;
  isMegaTopic?: boolean;
  lastId?: number | null;
}

/** Timeline excerpts exclude inaccessible posts, so requested entries may be absent. */
export interface PostStreamExcerpt {
  post_id: number;
  username: string | null;
  excerpt: string;
  action_code?: string;
  created_at?: string;
}

type PostId = number | string | null | undefined;
type LoadOptions = { background?: boolean };
type RefreshOptions = { preserveCooked?: boolean };
type PostPayload = PostCreateAttrs<Post> & Pick<Post, "id" | "post_number">;
type PostsResponse = {
  post_stream?: { posts?: PostPayload[] };
  suggested_topics?: Topic["suggested_topics"];
  suggested_group_name?: Topic["suggested_group_name"];
  user_badges?: Topic["user_badges"];
};
type PostStreamError = {
  jqXHR?: {
    status?: number;
    responseJSON?: { extras?: { html?: string; title?: string } };
  };
};
type PostRefreshRequest = {
  status: "pending" | "succeeded" | "failed";
  data?: PostPayload;
  error?: unknown;
};
type PostRefreshState = {
  preserveCooked: boolean;
  reconciled: Promise<void>;
  resolve: () => void;
  reject: (reason?: unknown) => void;
  requests: PostRefreshRequest[];
};
type ExcerptCache = (PostStreamExcerpt | undefined)[] & {
  loadNext?: number;
  loading?: globalThis.Promise<void> | null;
};

let _lastEditNotificationClick: {
  topicId: number;
  postNumber: number;
  revisionNumber: number;
} | null = null;

function comparePostTimestamps(
  candidate: string | undefined,
  reference: string | undefined
) {
  // Date.parse preserves its coercion of absent timestamps on partial posts.
  const candidateTime = Date.parse(candidate as string);
  const referenceTime = Date.parse(reference as string);
  const candidateIsValid = !Number.isNaN(candidateTime);
  const referenceIsValid = !Number.isNaN(referenceTime);

  if (candidateIsValid && referenceIsValid) {
    return candidateTime - referenceTime;
  }
  if (candidateIsValid) {
    return 1;
  }
  if (referenceIsValid) {
    return -1;
  }

  return candidate === reference ? 0 : 1;
}

/** Shared rendering marker, constructed by the legacy function below. */
export interface Placeholder {
  viewName: string;
}

export function Placeholder(this: Placeholder, viewName: string) {
  this.viewName = viewName;
}

export function setLastEditNotificationClick(
  topicId: number,
  postNumber: number,
  revisionNumber: number
) {
  _lastEditNotificationClick = {
    topicId,
    postNumber,
    revisionNumber,
  };
}

export function resetLastEditNotificationClick() {
  _lastEditNotificationClick = null;
}

/** Hydrated references and lazy caches must not emit own fields during construction. */
// eslint-disable-next-line @typescript-eslint/no-unsafe-declaration-merging
export default interface PostStream {
  id?: number;
  topic: Topic;
  appEvents: AppEventsService;
  _loadingPostIds?: number[] | null;
  /** Initialized before excerpt callbacks run; callbacks assume the cache is retained. */
  _excerpts?: ExcerptCache;
  /** TODO(typescript-pending): Core never supplies this nextWindow bound; remove when its source is established. */
  highest_post_number?: number;
}

// eslint-disable-next-line @typescript-eslint/no-unsafe-declaration-merging
export default class PostStream extends RestModel {
  /** The function remains a constructor at runtime; TypeScript functions have no construct signature. */
  static PLACEHOLDER = new (Placeholder as unknown as {
    new (viewName: string): Placeholder;
  })("post-placeholder");

  @service declare currentUser: User | null;
  @service declare store: StoreService;

  @tracked appendingPlaceholders = 0;
  @tracked filter: string | null | undefined;

  /** Topic hydration precedes this initializer; parseInt also coerces absent reply filters. */
  @tracked
  filterRepliesToPostNumber: number | false =
    parseInt(this.topic.replies_to_post_number as string, 10) || false;
  @tracked filterUpwardsPostID: number | false = false;

  /**
   * Post awaiting focus once rendered. A fresh object per request, so the
   * renderer can mark it `done` without writing tracked state mid-render.
   */
  @tracked focusTarget: { postNumber: number; done: boolean } | null = null;
  @tracked gaps: PostStreamData["gaps"];
  @tracked isMegaTopic: boolean | undefined;
  @tracked lastId: number | null | undefined;
  @tracked lastAppended: Post | undefined;
  @tracked loaded = false;
  @tracked loadingAbove = false;
  @tracked loadingBelow = false;
  @tracked loadingFilter = false;
  @tracked loadingLastPost = false;
  @tracked loadingNearPost: number | null | undefined;
  @tracked stagingPost = false;
  @tracked timelineLookup: [number, number][] | undefined = [];

  @autoTrackedArray posts: Post[] = [];
  @autoTrackedArray stream: number[] = [];
  @autoTrackedArray userFilters: string[] = [];

  quoteHighlights = trackedMap<number, { quote: string; revealed: boolean }>();
  _identityMap: Record<string, Post | null | undefined> = {};
  _pendingPostRefreshes = new Map<number, PostRefreshState>();

  @dependentKeyCompat
  get loading() {
    return (
      this.loadingAbove ||
      this.loadingBelow ||
      this.loadingFilter ||
      this.stagingPost
    );
  }

  @dependentKeyCompat
  get notLoading() {
    return !this.loading;
  }

  @dependentKeyCompat
  get firstPostNotLoaded() {
    return !this.firstPostPresent;
  }

  @dependentKeyCompat
  get lastPostNotLoaded() {
    return !this.loadedAllPosts;
  }

  @dependentKeyCompat
  get canAppendMore() {
    return this.notLoading && this.hasPosts && this.lastPostNotLoaded;
  }

  @dependentKeyCompat
  get canPrependMore() {
    return this.notLoading && this.hasPosts && this.firstPostNotLoaded;
  }

  @dependentKeyCompat
  get summary() {
    return this.filter === "summary";
  }

  @cached
  @dependentKeyCompat
  get postsWithPlaceholders(): (Post | Placeholder)[] {
    return (this.posts as (Post | Placeholder)[]).concat(
      Array.from(
        { length: this.appendingPlaceholders },
        () => PostStream.PLACEHOLDER
      )
    );
  }

  @dependentKeyCompat
  get filteredPostsCount() {
    return this.isMegaTopic
      ? this.topic.highest_post_number
      : this.stream.length;
  }

  @dependentKeyCompat
  get hasPosts() {
    return this.posts.length > 0;
  }

  @dependentKeyCompat
  get hasLoadedData() {
    return this.hasPosts && (this.filteredPostsCount as number) > 0;
  }

  @dependentKeyCompat
  get firstPostPresent() {
    if (!this.hasLoadedData) {
      return false;
    }

    return !!this.posts.find((item) => item.post_number === 1);
  }

  @dependentKeyCompat
  get firstPostId(): number | undefined {
    return this.stream[0];
  }

  @dependentKeyCompat
  get lastPostId(): number | null | undefined {
    return this.isMegaTopic ? this.lastId : this.stream.at(-1);
  }

  @dependentKeyCompat
  get loadedAllPosts() {
    if (!this.hasLoadedData) {
      return false;
    }
    if (this.lastPostId === -1) {
      return true;
    }

    return !!this.posts.find((item) => item.id === this.lastPostId);
  }

  /**
    Returns a JS Object of current stream filter options. It should match the query
    params for the stream.
  **/
  @dependentKeyCompat
  get streamFilters() {
    const result = trackedObject<PostStreamFilters>();

    if (this.filter) {
      result.filter = this.filter;
    }

    if (!isEmpty(this.userFilters)) {
      result.username_filters = this.userFilters.join(",");
    }

    if (this.filterRepliesToPostNumber) {
      result.replies_to_post_number = this.filterRepliesToPostNumber;
    }

    if (this.filterUpwardsPostID) {
      result.filter_upwards_post_id = this.filterUpwardsPostID;
    }

    return result;
  }

  @dependentKeyCompat
  get hasNoFilters() {
    return (
      !this.streamFilters ||
      (this.streamFilters.filter !== "summary" &&
        !this.streamFilters.username_filters)
    );
  }

  /**
    Returns the window of posts above the current set in the stream, bound to the top of the stream.
    This is the collection we'll ask for when scrolling upwards.
  **/
  @dependentKeyCompat
  get previousWindow() {
    if (!this.posts) {
      return [];
    }

    // If we can't find the last post loaded, bail
    const firstPost = this.posts[0];
    if (!firstPost) {
      return [];
    }

    // Find the index of the last post loaded, if not found, bail
    const stream = this.stream;
    const firstIndex = this.indexOf(firstPost);
    if (firstIndex === -1) {
      return [];
    }

    let startIndex = firstIndex - this.topic.chunk_size!;
    if (startIndex < 0) {
      startIndex = 0;
    }
    return stream.slice(startIndex, firstIndex);
  }

  /**
    Returns the window of posts below the current set in the stream, bound by the bottom of the
    stream. This is the collection we use when scrolling downwards.
  **/
  @dependentKeyCompat
  get nextWindow() {
    const lastLoadedPost = this.posts.at(-1);

    // If we can't find the last post loaded, bail
    if (!lastLoadedPost) {
      return [];
    }

    // Find the index of the last post loaded, if not found, bail
    const lastIndex = this.indexOf(lastLoadedPost);
    if (lastIndex === -1) {
      return [];
    }
    // Preserve the numeric comparison against the currently unsupplied stream bound.
    if (lastIndex + 1 >= (this.highest_post_number as number)) {
      return [];
    }

    // find our window of posts
    return this.stream.slice(
      lastIndex + 1,
      lastIndex + this.topic.chunk_size! + 1
    );
  }

  get loadedPosts() {
    // Boolean filtering removes null tombstones and absent entries.
    return Object.values(this._identityMap).filter(Boolean) as Post[];
  }

  /**
   * Moves focus to a post once it is rendered, so keyboard and screen reader
   * users continue from there. The first post is skipped, as the page start
   * already leads to it.
   */
  focusPostOnRender(postNumber: number) {
    if (postNumber > 1) {
      this.focusTarget = { postNumber, done: false };
    }
  }

  highlightQuoteOnRender(postNumber: number, quote?: string) {
    if (quote === undefined) {
      return;
    }

    [...this.quoteHighlights.keys()].forEach((key) =>
      this.quoteHighlights.delete(key)
    );
    this.quoteHighlights.set(postNumber, { quote, revealed: false });
  }

  cancelFilter() {
    this.streamFilters.mixedHiddenPosts = false;

    this.setProperties({
      userFilters: [],
      filterRepliesToPostNumber: false,
      filterUpwardsPostID: false,
      filter: null,
    });
  }

  refreshAndJumpToSecondVisible() {
    return this.refresh({}).then(() => {
      if (this.posts?.length > 1) {
        DiscourseURL.jumpToPost(this.posts[1].post_number);
      }
    });
  }

  showTopReplies() {
    this.cancelFilter();
    this.filter = "summary";
    return this.refreshAndJumpToSecondVisible();
  }

  /** Filter the stream to a particular user. */
  filterParticipant(username: string) {
    this.cancelFilter();

    if (!this.userFilters.includes(username)) {
      this.userFilters.push(username);
    }

    return this.refreshAndJumpToSecondVisible();
  }

  filterReplies(postNumber: number, postId: number) {
    this.cancelFilter();
    this.filterRepliesToPostNumber = postNumber;

    this.appEvents.trigger("post-stream:filter-replies", {
      topic_id: this.topic.id,
      post_number: postNumber,
      post_id: postId,
    });

    return this.refresh({ refreshInPlace: true }).then(() => {
      const element = document.querySelector(`#post_${postNumber}`);

      // order is important, we need to get the offset before triggering a refresh
      const originalTopOffset = element
        ? element.getBoundingClientRect().top
        : null;

      DiscourseURL.jumpToPost(postNumber, { originalTopOffset });
      this.focusPostOnRender(postNumber);
    });
  }

  filterUpwards(postId: number) {
    this.cancelFilter();
    this.filterUpwardsPostID = postId;
    this.appEvents.trigger("post-stream:filter-upwards", {
      topic_id: this.topic.id,
      post_id: postId,
    });

    return this.refresh({ refreshInPlace: true }).then(() => {
      if (this.posts?.length > 1) {
        const postNumber = this.posts[1].post_number;
        DiscourseURL.jumpToPost(postNumber, { skipIfOnScreen: true });
        this.focusPostOnRender(postNumber);
      }
    });
  }

  /**
    Loads a new set of posts into the stream. If you provide a `nearPost` option and the post
    is already loaded, it will simply scroll there and load nothing.
  **/
  refresh(opts?: PostStreamRefreshOptions): globalThis.Promise<void> {
    opts ||= {};
    // parseInt retains number/string coercion; the assignment makes loadingNearPost numeric.
    if (opts.nearPost) {
      opts.nearPost = parseInt(opts.nearPost as string, 10);
    }

    if (opts.cancelFilter) {
      this.cancelFilter();
      delete opts.cancelFilter;
    }

    // Do we already have the post in our list of posts? Jump there.
    if (opts.forceLoad) {
      this.loaded = false;
    } else {
      const postWeWant = this.posts.find(
        (p) => p.post_number === opts!.nearPost
      );
      if (postWeWant) {
        return Promise.resolve<void>().then(() =>
          this._checkIfShouldShowRevisions()
        );
      }
    }

    // TODO: if we have all the posts in the filter, don't go to the server for them.
    if (!opts.refreshInPlace) {
      this.loadingFilter = true;
    }
    this.loadingNearPost = opts.nearPost as number | undefined;

    opts = deepMerge(opts, this.streamFilters);

    // Request a topicView
    return loadTopicView(this.topic, opts!)
      .then((json) => {
        // TODO(typescript-pending): TopicResponse leaves post_stream unknown; remove when its payload contract is typed.
        this.updateFromJson(json.post_stream as PostStreamData | undefined);
        this.setProperties({
          loadingFilter: false,
          timelineLookup: json.timeline_lookup,
          loaded: true,
        });
        this._checkIfShouldShowRevisions();

        // Reset all error props
        this.topic.setProperties({
          errorLoading: false,
          errorTitle: null,
          errorHtml: null,
          errorMessage: null,
          noRetry: false,
        });
      })
      .catch((result: PostStreamError) => {
        this.errorLoading(result);
        // Error retains its existing coercion of the transport error to a message.
        throw new Error(result as unknown as string);
      })
      .finally(() => {
        this.loadingNearPost = null;
      });
  }

  /** Fill in a gap of posts before a particular post. */
  async fillGapBefore(post: Post, gap: number[]) {
    const postId = post.id;
    const index = this.stream.indexOf(postId);

    if (index === -1) {
      return;
    }

    // Insert the gap at the appropriate place
    let postIndex = this.posts.indexOf(post);

    const headGap = gap.slice(0, this.topic.chunk_size);
    const tailGap = gap.slice(this.topic.chunk_size);
    // eslint-disable-next-line prefer-spread -- Preserve the existing apply dispatch.
    this.stream.splice.apply(
      this.stream,
      [index, 0].concat(headGap) as [number, number, ...number[]]
    );

    if (postIndex !== -1) {
      const posts = await this.findPostsByIds(headGap);
      posts.forEach((p) => {
        this._initUserModels(p);
        const stored = this.storePost(p);

        if (!this.posts.includes(stored)) {
          this.posts.splice(postIndex++, 0, stored);
        }
      });

      if (tailGap.length > 0) {
        this.gaps!.before[postId] = tailGap;
      } else {
        delete this.gaps!.before[postId];
      }

      post.hasGap = false;
      this.gapExpanded();
    }
  }

  /** Fill in a gap of posts after a particular post. */
  async fillGapAfter(post: Post, gap: number[]) {
    const postId = post.id;
    const index = this.stream.indexOf(postId);

    if (index === -1) {
      return;
    }

    this.stream.push(...gap);

    await this.appendMore();
    delete this.gaps!.after[postId];
    this.gapExpanded();
  }

  gapExpanded() {
    // resets the reply count in posts-filtered-notice
    // because once a gap has been expanded that count is no longer exact
    if (this.streamFilters?.replies_to_post_number) {
      this.streamFilters.mixedHiddenPosts = true;
    }
  }

  /** Appends the next window of posts to the stream. Call it when scrolling downwards. */
  async appendMore() {
    // Make sure we can append more posts
    if (!this.canAppendMore) {
      return;
    }

    if (this.isMegaTopic) {
      this.loadingBelow = true;
      this.appendingPlaceholders += this.topic.chunk_size! - 1;

      try {
        await this.fetchNextWindow(
          this.posts.at(-1)!.post_number,
          true,
          (p) => {
            this.appendPost(p);
          }
        );
      } finally {
        this.appendingPlaceholders -= this.topic.chunk_size! - 1;
        this.loadingBelow = false;
      }
    } else {
      const postIds = this.nextWindow;
      if (isEmpty(postIds)) {
        return;
      }

      this.loadingBelow = true;
      this.appendingPlaceholders += postIds.length;

      try {
        const posts = await this.findPostsByIds(postIds);
        posts.forEach((p) => this.appendPost(p));
        return posts;
      } finally {
        this.appendingPlaceholders -= postIds.length;
        this.loadingBelow = false;
      }
    }
  }

  /** Prepend the previous window of posts to the stream. Call it when scrolling upwards. */
  async prependMore({ beforePrepend }: { beforePrepend?: () => void } = {}) {
    // Make sure we can append more posts
    if (!this.canPrependMore) {
      return;
    }

    if (this.isMegaTopic) {
      this.loadingAbove = true;

      try {
        let captured = false;
        await this.fetchNextWindow(this.posts[0].post_number, false, (p) => {
          // Capture the anchor position before the first post is inserted.
          // The network await above gave Ember time to render the spinner.
          if (!captured) {
            beforePrepend?.();
            captured = true;
          }
          this.prependPost(p);
        });
      } finally {
        this.loadingAbove = false;
      }
    } else {
      const postIds = this.previousWindow;
      if (isEmpty(postIds)) {
        return;
      }
      this.loadingAbove = true;

      try {
        const posts = await this.findPostsByIds(postIds.reverse());
        // Capture the anchor position after the fetch (spinner rendered during
        // the await) and before inserting new posts into the stream.
        beforePrepend?.();
        posts.forEach((p) => this.prependPost(p));
      } finally {
        this.loadingAbove = false;
      }
    }
  }

  /**
    Stage a post for insertion in the stream. It should be rendered right away under the
    assumption that the post will succeed. We can then `commitPost` when it succeeds or
    `undoPost` when it fails.
  **/
  stagePost(post: Post, user: User): "alreadyStaging" | "staged" | "offScreen" {
    // We can't stage two posts simultaneously
    if (this.stagingPost) {
      return "alreadyStaging";
    }

    this.stagingPost = true;

    this.topic.setProperties({
      posts_count: (this.topic.posts_count || 0) + 1,
      last_posted_at: new Date().toISOString(),
      "details.last_poster": user,
      highest_post_number: (this.topic.highest_post_number || 0) + 1,
    });

    post.setProperties({
      post_number: this.topic.highest_post_number,
      topic: this.topic,
      created_at: new Date(),
      id: -1,
    });

    // If we're at the end of the stream, add the post
    if (this.loadedAllPosts) {
      this.appendPost(post);
      if (!this.stream.includes(post.id)) {
        this.stream.push(post.id);
      }

      return "staged";
    }

    return "offScreen";
  }

  /** Commit the post we staged. Call this after a save succeeds. */
  commitPost(post: Post) {
    if (this.topic.id === post.topic_id) {
      if (this.loadedAllPosts) {
        this.appendPost(post);
        if (!this.stream.includes(post.id)) {
          this.stream.push(post.id);
        }
      }
    }

    removeValueFromArray(this.stream, -1);
    this._identityMap[-1] = null;
    this.stagingPost = false;
  }

  /**
    Undo a post we've staged in the stream. Remove it from being rendered and revert the
    state we changed.
  **/
  undoPost(post: Post) {
    removeValueFromArray(this.stream, -1);
    removeValueFromArray(this.posts, post);
    this._identityMap[-1] = null;

    const topic = this.topic;
    this.stagingPost = false;

    topic.setProperties({
      highest_post_number: (topic.highest_post_number || 0) - 1,
      posts_count: (topic.posts_count || 0) - 1,
    });

    // TODO unfudge reply count on parent post
  }

  prependPost(post: Post) {
    this._initUserModels(post);
    const stored = this.storePost(post);

    if (stored && !this.posts.includes(stored)) {
      this.posts.unshift(stored);
    }

    return post;
  }

  appendPost(post: Post) {
    this._initUserModels(post);
    const stored = this.storePost(post);

    if (stored) {
      if (!this.posts.includes(stored)) {
        this.posts.push(stored);
      }

      if (stored.id !== -1) {
        this.lastAppended = stored;
      }
    }

    return post;
  }

  removePosts(posts: Post[]) {
    if (isEmpty(posts)) {
      return;
    }

    const postIds = posts.map((p) => p.id);

    removeValuesFromArray(this.stream, postIds);
    removeValuesFromArray(this.posts, posts);
    postIds.forEach((id) => delete this._identityMap[id as string | number]);
  }

  removeAllPosts() {
    // The truthy predicate excludes staged tombstones and absent entries.
    const posts = Object.values(this._identityMap).filter((p) => p) as Post[];
    this.removePosts(posts);
  }

  /** Returns a stored post, a staged tombstone, or an absent entry; IDs retain object-key coercion. */
  findLoadedPost(id: PostId): Post | null | undefined {
    return this._identityMap[id as string | number];
  }

  loadPostByPostNumber(postNumber: number) {
    const url = `/posts/by_number/${this.topic.id}/${postNumber}`;

    return ajax(url).then((post: PostPayload) => {
      return this.storePost(this.store.createRecord("post", post));
    });
  }

  loadNearestPostToDate(date: string) {
    const url = `/posts/by-date/${this.topic.id}/${date}`;

    return ajax(url).then((post: PostPayload) => {
      return this.storePost(this.store.createRecord("post", post));
    });
  }

  /** Nullish and DOM-string IDs retain the existing key and URL coercion. */
  loadPost(postId: PostId) {
    const existing = this._identityMap[postId as string | number];

    return ajax(`/posts/${postId}`).then((p: PostPayload) => {
      if (existing) {
        p.cooked = existing.cooked;
      }

      return this.storePost(this.store.createRecord("post", p));
    });
  }

  /* mainly for backwards compatibility with plugins, used in quick messages plugin
   * TODO: remove July 2022
   * */
  triggerNewPostInStream(postId: number, opts?: LoadOptions) {
    deprecated(
      "Please use triggerNewPostsInStream, this method will be removed July 2021",
      {
        id: "discourse.post-stream.trigger-new-post",
      }
    );
    return this.triggerNewPostsInStream([postId], opts);
  }

  /**
    Finds and adds posts to the stream by id. Typically this would happen if we receive a message
    from the message bus indicating there's a new post. We'll only insert it if we currently
    have no filters.
  **/
  async triggerNewPostsInStream(
    postIds: number[] | null | undefined,
    opts?: LoadOptions
  ) {
    // Early return if no posts or empty array
    if (!postIds || postIds.length === 0) {
      return;
    }

    // Early return if there are filters active
    if (!this.hasNoFilters) {
      return;
    }

    this._loadingPostIds = this._loadingPostIds || [];

    // Find missing post IDs that aren't in the stream
    const missingIds = postIds.filter(
      (postId) => postId && !this.stream.includes(postId)
    );

    if (missingIds.length === 0) {
      return;
    }

    if (this.loadedAllPosts) {
      // Add missing posts to loading queue if not already loading
      missingIds.forEach((postId) => {
        if (!this._loadingPostIds!.includes(postId)) {
          this._loadingPostIds!.push(postId);
        }
      });

      this.loadingLastPost = true;

      try {
        const posts = await this.findPostsByIds(this._loadingPostIds, opts);
        this._loadingPostIds = null;

        const ignoredUsers = this.currentUser?.ignored_users;
        posts.forEach((p) => {
          if (ignoredUsers?.includes(p.username!)) {
            removeValueFromArray(this.stream, p.id);
            return;
          }

          if (!this.stream.includes(p.id)) {
            this.stream.push(p.id);
          }
          this.appendPost(p);
        });
      } finally {
        this.loadingLastPost = false;
      }
    } else {
      // Simply add missing post IDs to the stream
      missingIds.forEach((postId) => {
        if (!this.stream.includes(postId)) {
          this.stream.push(postId);
        }
      });
    }
  }

  async triggerRecoveredPost(postId: number) {
    const existing = this._identityMap[postId];

    if (existing) {
      return this.refreshPost(postId);
    }

    // need to insert into stream
    const p: PostPayload = await ajax(`/posts/${postId}`);
    const post = this.store.createRecord("post", p);
    this.storePost(post);

    // we need to zip this into the stream
    let index = 0;
    this.stream.forEach((pid) => {
      if (pid < p.id) {
        index += 1;
      }
    });

    this.stream.splice(index, 0, p.id);

    index = 0;
    this.posts.forEach((_post) => {
      if (_post.id < p.id) {
        index += 1;
      }
    });

    if (index < this.posts.length) {
      this.posts.splice(index, 0, post);
    } else {
      if (post.post_number < this.posts.at(-1)!.post_number + 5) {
        await this.appendMore();
      }
    }
  }

  triggerDeletedPost(postId: number) {
    const existing = this._identityMap[postId];

    if (existing && !existing.deleted_at) {
      return ajax(`/posts/${postId}`)
        .then((p: PostPayload) => {
          this.storePost(this.store.createRecord("post", p));
        })
        .catch(() => {
          this.removePosts([existing]);
        });
    }

    return Promise.resolve<void>();
  }

  triggerDestroyedPost(postId: number) {
    const existing = this._identityMap[postId];
    // The existing implementation forwards an absent entry and removePosts dereferences it.
    this.removePosts([existing as Post]);
    return Promise.resolve<void>();
  }

  /**
   * Fetches and stores the authoritative state of a loaded post.
   *
   * @param opts - preserveCooked retains the loaded cooked HTML.
   */
  refreshPost(postId: number, opts: RefreshOptions | null = {}): Promise<void> {
    opts ||= {};

    const existing = this._identityMap[postId];
    if (!existing) {
      return Promise.resolve<void>();
    }
    postId = existing.id;

    let refreshState = this._pendingPostRefreshes.get(postId);
    if (!refreshState) {
      let resolve!: () => void;
      let reject!: (reason?: unknown) => void;
      const reconciled = new Promise<void>((promiseResolve, promiseReject) => {
        resolve = promiseResolve;
        reject = promiseReject;
      });
      refreshState = {
        preserveCooked: true,
        reconciled,
        reject,
        requests: [],
        resolve,
      };
      this._pendingPostRefreshes.set(postId, refreshState);
    }

    refreshState.preserveCooked &&= Boolean(opts.preserveCooked);
    const refresh: PostRefreshRequest = { status: "pending" };
    refreshState.requests.push(refresh);

    void ajax(`/posts/${postId}`).then(
      (data: PostPayload) => {
        refresh.data = data;
        refresh.status = "succeeded";
        this._reconcilePostRefresh(postId, refreshState);
      },
      (error: unknown) => {
        refresh.error = error;
        refresh.status = "failed";
        this._reconcilePostRefresh(postId, refreshState);
      }
    );

    return refreshState.reconciled;
  }

  /**
   * Updates a post in the stream when it has been changed on the server.
   *
   * @param updatedAt - The time when the change event was published.
   * @param opts - preserveCooked retains the loaded cooked HTML.
   */
  async triggerChangedPost(
    postId: number,
    updatedAt: string,
    opts: RefreshOptions = {}
  ) {
    const existing = this._identityMap[postId];

    if (existing && comparePostTimestamps(updatedAt, existing.updated_at) > 0) {
      return this.refreshPost(postId, opts);
    }
  }

  triggerLikedPost(
    postId: number,
    likesCount: number,
    userID: number,
    eventType: string
  ) {
    const resolved = Promise.resolve<void>();

    const post = this.findLoadedPost(postId);
    if (post) {
      post.updateLikeCount(likesCount, userID, eventType);
      this.storePost(post);
    }

    return resolved;
  }

  triggerReadPost(postId: number, readersCount: number) {
    const resolved = Promise.resolve<void>();

    resolved.then(() => {
      const post = this.findLoadedPost(postId);
      if (post && readersCount > (post.readers_count as number)) {
        post.readers_count = readersCount;
        this.storePost(post);
      }
    });

    return resolved;
  }

  triggerChangedTopicStats() {
    if (this.firstPostNotLoaded) {
      return Promise.reject();
    }

    return Promise.resolve<void>().then(() => {
      const firstPost = this.posts.find((p) => p.post_number === 1);
      return firstPost!.id;
    });
  }

  postForPostNumber(postNumber: number) {
    if (!this.hasPosts) {
      return;
    }

    return this.posts.find((p) => {
      return p.post_number === postNumber;
    });
  }

  /**
    Returns the closest post given a postNumber that may not exist in the stream.
    For example, if the user asks for a post that's deleted or otherwise outside the range.
    This allows us to set the progress bar with the correct number.
  **/
  closestPostForPostNumber(
    postNumber: number | string
  ): Post | null | undefined {
    if (!this.hasPosts) {
      return;
    }

    let closest: Post | null = null;
    this.posts.forEach((p) => {
      if (!closest) {
        closest = p;
        return;
      }

      if (
        Math.abs((postNumber as number) - p.post_number) <
        Math.abs(closest.post_number - (postNumber as number))
      ) {
        closest = p;
      }
    });

    return closest;
  }

  /** Get the index of a post in the stream. (Use this for the topic progress bar.) */
  progressIndexOfPost(post: Post) {
    return this.progressIndexOfPostId(post);
  }

  /** Returns the progress index of a Post object, despite the method name; mega topics use its post_number. */
  progressIndexOfPostId(post: Post) {
    const postId = post.id;

    if (this.isMegaTopic) {
      return post.post_number;
    } else {
      return this.stream.indexOf(postId) + 1;
    }
  }

  /**
    Returns the closest post number given a postNumber that may not exist in the stream.
    For example, if the user asks for a post that's deleted or otherwise outside the range.
    This allows us to set the progress bar with the correct number.
  **/
  closestPostNumberFor(postNumber: number | string): number | null | undefined {
    if (!this.hasPosts) {
      return;
    }

    let closest: number | null = null;
    this.posts.forEach((p) => {
      if (closest === postNumber) {
        return;
      }
      if (!closest) {
        closest = p.post_number;
      }

      if (
        Math.abs((postNumber as number) - p.post_number) <
        Math.abs(closest - (postNumber as number))
      ) {
        closest = p.post_number;
      }
    });

    return closest;
  }

  closestDaysAgoFor(postNumber: number) {
    const timelineLookup = this.timelineLookup || [];

    let low = 0;
    let high = timelineLookup.length - 1;

    while (low <= high) {
      const mid = Math.floor(low + (high - low) / 2);
      const midValue = timelineLookup[mid][0];

      if (midValue > postNumber) {
        high = mid - 1;
      } else if (midValue < postNumber) {
        low = mid + 1;
      } else {
        return timelineLookup[mid][1];
      }
    }

    const val = timelineLookup[high] || timelineLookup[low];
    if (val) {
      return val[1];
    }
  }

  /** Find a postId for a postNumber, respecting gaps */
  findPostIdForPostNumber(postNumber: number): number | undefined {
    const beforeLookup = this.gaps?.before;

    let sum = 1;
    for (let i = 0; i < this.stream.length; i++) {
      const pid = this.stream[i];

      // See if there are posts before this post
      if (beforeLookup) {
        const before = beforeLookup[pid];
        if (before) {
          for (let j = 0; j < before.length; j++) {
            if (sum === postNumber) {
              return pid;
            }
            sum++;
          }
        }
      }

      if (sum === postNumber) {
        return pid;
      }

      sum++;
    }
  }

  updateFromJson(postStreamData?: PostStreamData | null) {
    applyBehaviorTransformer(
      "post-stream-update-from-json",
      () => {
        this.posts.length = 0;
        this.gaps = null;

        if (postStreamData) {
          // Load posts if present
          postStreamData.posts.forEach((p) =>
            this.appendPost(this.store.createRecord("post", p))
          );
          delete (postStreamData as Partial<PostStreamData>).posts;

          // Update our attributes
          postStreamData.gaps = {
            before: trackedObject(postStreamData.gaps?.before || {}),
            after: trackedObject(postStreamData.gaps?.after || {}),
          };
          this.setProperties(
            postStreamData as Partial<PostStreamData> & RestPayload
          );
        }
      },
      { postStream: this }
    );
  }

  /**
    Stores a post in our identity map, and sets up the references it needs to
    find associated objects like the topic. It might return a different reference
    than you supplied if the post has already been loaded.
  **/
  storePost(post: Post): Post;
  storePost(post: undefined | null): undefined;
  storePost(post: Post | null | undefined): Post | undefined;
  storePost(post: Post | null | undefined) {
    // Calling `get(undefined)` raises an error
    if (!post) {
      return;
    }

    const postId = get(post, "id");
    if (postId) {
      const existing = this._identityMap[post.id];

      // Update the `highest_post_number` if this post is higher.
      const postNumber = post.post_number;
      if (postNumber && postNumber > (this.topic.highest_post_number || 0)) {
        this.topic.highest_post_number = postNumber;
        // TODO(typescript-pending): Topic's timestamp type excludes the Date copied from staged posts; remove when that contract includes staging.
        (
          this.topic as Omit<Topic, "last_posted_at"> & {
            last_posted_at?: string | Date | null;
          }
        ).last_posted_at = post.created_at;
      }

      if (existing) {
        // If the post is in the identity map, update it and return the old reference.
        existing.updateFromPost(post);
        return existing;
      }

      if (post.topic !== this.topic) {
        post.topic = this.topic;
      }
      this._identityMap[post.id] = post;
    }

    return post;
  }

  fetchNextWindow(
    postNumber: number,
    asc: boolean,
    callback?: (this: PostStream, post: Post) => void
  ) {
    let data = {
      post_number: postNumber,
      asc,
      include_suggested: !this.topic.suggested_topics,
    };

    data = deepMerge(data, this.streamFilters);

    return ajax(`/t/${this.topic.id}/posts.json`, { data })
      .then((result: PostsResponse) => {
        this._setSuggestedTopics(result);

        const posts = get(result, "post_stream.posts") as
          | PostPayload[]
          | undefined;

        if (posts) {
          posts.forEach((p: PostPayload | Post) => {
            p = this.storePost(
              this.store.createRecord("post", p as PostPayload)
            );

            if (callback) {
              callback.call(this, p);
            }
          });
        }
      })
      .catch((error: PostStreamError) => {
        // If we get a 403 error, refresh the window to prevent continuous retries
        if (error.jqXHR && error.jqXHR.status === 403) {
          window.location.reload();
          return;
        }
      });
  }

  async findPostsByIds(postIds: PostId[], opts?: LoadOptions) {
    const unloaded = postIds.filter(
      (p) => !this._identityMap[p as string | number]
    );

    // Load our unloaded posts by id
    await this.loadIntoIdentityMap(unloaded, opts);

    return postIds
      .map((p) => this._identityMap[p as string | number])
      .filter((item) => item != null);
  }

  async loadIntoIdentityMap(
    postIds: PostId[],
    opts?: LoadOptions
  ): globalThis.Promise<Post[] | undefined> {
    if (isEmpty(postIds)) {
      return [];
    }

    const data = {
      post_ids: postIds,
      include_suggested: !this.topic.suggested_topics,
    };

    // eslint-disable-next-line prefer-const -- Preserve the emitted declaration.
    let headers: Record<string, string> = {};
    if (opts?.background) {
      headers["Discourse-Background"] = "true";
    }

    try {
      const result: PostsResponse = await ajax(
        `/t/${this.topic.id}/posts.json`,
        {
          data,
          headers,
        }
      );

      this._setSuggestedTopics(result);
      if (result.user_badges) {
        this.topic.user_badges ??= {};
        Object.assign(this.topic.user_badges, result.user_badges);
      }

      const posts = get(result, "post_stream.posts") as
        | PostPayload[]
        | undefined;

      if (posts) {
        posts.forEach((p) =>
          this.storePost(this.store.createRecord("post", p))
        );
      }
    } catch (error) {
      // If we get a 403 error, refresh the window to prevent continuous retries
      if ((error as PostStreamError).jqXHR?.status === 403) {
        window.location.reload();
        return;
      }
      throw error;
    }
  }

  backfillExcerpts(streamPosition: number): globalThis.Promise<void> {
    this._excerpts ||= [];
    this._excerpts.loadNext = streamPosition;

    if (this._excerpts!.loading) {
      return this._excerpts!.loading.then(() => {
        if (
          !this._excerpts![this.stream[streamPosition]] &&
          this._excerpts!.loadNext === streamPosition
        ) {
          return this.backfillExcerpts(streamPosition);
        }
      });
    }

    // eslint-disable-next-line prefer-const -- Preserve the emitted declaration.
    let postIds = this.stream.slice(
      Math.max(streamPosition - 20, 0),
      streamPosition + 20
    );

    for (let i = postIds.length - 1; i >= 0; i--) {
      if (this._excerpts[postIds[i]]) {
        postIds.splice(i, 1);
      }
    }

    // eslint-disable-next-line prefer-const -- Preserve the emitted declaration.
    let data = {
      post_ids: postIds,
    };

    this._excerpts!.loading = ajax(`/t/${this.topic.id}/excerpts.json`, {
      data,
    })
      .then((excerpts: PostStreamExcerpt[]) => {
        excerpts.forEach((obj) => {
          this._excerpts![obj.post_id] = obj;
        });
      })
      .finally(() => {
        this._excerpts!.loading = null;
      });

    return this._excerpts!.loading;
  }

  excerpt(streamPosition: number): Promise<PostStreamExcerpt | "" | undefined> {
    if (this.isMegaTopic) {
      return new Promise<"">((resolve) => resolve(""));
    }

    return new Promise((resolve, reject) => {
      const excerpt = this._excerpts?.[this.stream[streamPosition]];

      if (excerpt) {
        resolve(excerpt);
        return;
      }

      this.backfillExcerpts(streamPosition)
        .then(() => {
          resolve(this._excerpts![this.stream[streamPosition]]);
        })
        .catch((e: unknown) => reject(e));
    });
  }

  indexOf(post: Post) {
    return this.stream.indexOf(post.id);
  }

  /** Handles an error loading a topic based on a HTTP status code. Updates the text to the correct values. */
  errorLoading(error: PostStreamError) {
    applyBehaviorTransformer(
      "post-stream-error-loading",
      () => {
        this.loadingFilter = false;
        this.topic.errorLoading = true;

        if (!error.jqXHR) {
          throw error;
        }

        const json = error.jqXHR.responseJSON;
        if (json?.extras?.html) {
          this.topic.errorTitle = json.extras.title;
          this.topic.errorHtml = json.extras.html;
        } else {
          this.topic.errorMessage = i18n("topic.server_error.description");
          this.topic.noRetry = error.jqXHR.status === 403;
        }
      },
      {
        topic: this.topic,
        error,
      }
    );
  }

  _reconcilePostRefresh(postId: number, refreshState: PostRefreshState) {
    if (this._pendingPostRefreshes.get(postId) !== refreshState) {
      return;
    }

    for (
      let requestIndex = refreshState.requests.length - 1;
      requestIndex >= 0;
      requestIndex--
    ) {
      const refresh = refreshState.requests[requestIndex];
      if (refresh.status === "pending") {
        return;
      }

      if (refresh.status === "succeeded") {
        const latest = this._identityMap[postId];
        if (
          latest &&
          comparePostTimestamps(refresh.data!.updated_at, latest.updated_at) >=
            0
        ) {
          if (refreshState.preserveCooked) {
            refresh.data!.cooked = latest.cooked;
          }
          this.storePost(this.store.createRecord("post", refresh.data!));
        }

        this._pendingPostRefreshes.delete(postId);
        refreshState.resolve();
        return;
      }
    }

    this._pendingPostRefreshes.delete(postId);
    refreshState.reject(refreshState.requests.at(-1)!.error);
  }

  _initUserModels(post: Post) {
    if (post.mentioned_users) {
      post.mentioned_users = post.mentioned_users.map((u) =>
        this.store.createRecord("user", u)
      );
    }
  }

  _checkIfShouldShowRevisions() {
    if (!_lastEditNotificationClick) {
      return;
    }

    const copy = _lastEditNotificationClick;
    resetLastEditNotificationClick();
    const postsNumbers = this.posts.map((post) => post.post_number);

    if (
      copy.topicId === this.topic.id &&
      postsNumbers.includes(copy.postNumber)
    ) {
      schedule("afterRender", () => {
        this.appEvents.trigger(
          "post:show-revision",
          copy.postNumber,
          copy.revisionNumber
        );
      });
    }
  }

  _setSuggestedTopics(result: PostsResponse) {
    applyBehaviorTransformer(
      "post-stream-suggested-topics",
      () => {
        if (!result.suggested_topics) {
          return;
        }

        this.topic.setProperties({
          suggested_topics: result.suggested_topics,
          suggested_group_name: result.suggested_group_name,
        });
      },
      { postStream: this, result }
    );
  }
}
