import { cached, tracked } from "@glimmer/tracking";
import { get } from "@ember/object";
import { dependentKeyCompat } from "@ember/object/compat";
import { schedule } from "@ember/runloop";
import { service } from "@ember/service";
import { isEmpty } from "@ember/utils";
import { TrackedObject } from "@ember-compat/tracked-built-ins";
import { Promise } from "rsvp";
import { ajax } from "discourse/lib/ajax";
import {
  removeValueFromArray,
  removeValuesFromArray,
} from "discourse/lib/array-tools";
import deprecated from "discourse/lib/deprecated";
import { deepMerge } from "discourse/lib/object";
import { trackedArray } from "discourse/lib/tracked-tools";
import { applyBehaviorTransformer } from "discourse/lib/transformer";
import DiscourseURL from "discourse/lib/url";
import { highlightPost } from "discourse/lib/utilities";
import RestModel from "discourse/models/rest";
import { loadTopicView } from "discourse/models/topic";
import { i18n } from "discourse-i18n";

let _lastEditNotificationClick = null;

export function Placeholder(viewName) {
  this.viewName = viewName;
}

export function setLastEditNotificationClick(
  topicId,
  postNumber,
  revisionNumber
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

export default class PostStream extends RestModel {
  static PLACEHOLDER = new Placeholder("post-placeholder");

  @service currentUser;
  @service store;

  @tracked appendingPlaceholders = 0;
  @tracked filter;
  @tracked
  filterRepliesToPostNumber =
    parseInt(this.topic.replies_to_post_number, 10) || false;
  @tracked filterUpwardsPostID = false;
  @tracked gaps;
  @tracked isMegaTopic;
  @tracked lastId;
  @tracked lastAppended;
  @tracked loaded = false;
  @tracked loadingAbove = false;
  @tracked loadingBelow = false;
  @tracked loadingFilter = false;
  @tracked loadingLastPost = false;
  @tracked loadingNearPost;
  @tracked stagingPost = false;
  @tracked timelineLookup = [];

  @trackedArray posts = [];
  @trackedArray stream = [];
  @trackedArray userFilters = [];

  _identityMap = {};

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
  get postsWithPlaceholders() {
    return this.posts.concat(
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
    return this.hasPosts && this.filteredPostsCount > 0;
  }

  @dependentKeyCompat
  get firstPostPresent() {
    if (!this.hasLoadedData) {
      return false;
    }

    return !!this.posts.find((item) => item.post_number === 1);
  }

  @dependentKeyCompat
  get firstPostId() {
    return this.stream[0];
  }

  @dependentKeyCompat
  get lastPostId() {
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
    const result = new TrackedObject();

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

    let startIndex = firstIndex - this.topic.chunk_size;
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
    if (lastIndex + 1 >= this.highest_post_number) {
      return [];
    }

    // find our window of posts
    return this.stream.slice(
      lastIndex + 1,
      lastIndex + this.topic.chunk_size + 1
    );
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

  // Filter the stream to a particular user.
  filterParticipant(username) {
    this.cancelFilter();

    if (!this.userFilters.includes(username)) {
      this.userFilters.push(username);
    }

    return this.refreshAndJumpToSecondVisible();
  }

  filterReplies(postNumber, postId) {
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

      schedule("afterRender", () => highlightPost(postNumber));
    });
  }

  filterUpwards(postId) {
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

        schedule("afterRender", () => highlightPost(postNumber));
      }
    });
  }

  /**
    Loads a new set of posts into the stream. If you provide a `nearPost` option and the post
    is already loaded, it will simply scroll there and load nothing.
  **/
  refresh(opts) {
    opts ||= {};
    if (opts.nearPost) {
      opts.nearPost = parseInt(opts.nearPost, 10);
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
        (p) => p.post_number === opts.nearPost
      );
      if (postWeWant) {
        return Promise.resolve().then(() => this._checkIfShouldShowRevisions());
      }
    }

    // TODO: if we have all the posts in the filter, don't go to the server for them.
    if (!opts.refreshInPlace) {
      this.loadingFilter = true;
    }
    this.loadingNearPost = opts.nearPost;

    opts = deepMerge(opts, this.streamFilters);

    // Request a topicView
    return loadTopicView(this.topic, opts)
      .then((json) => {
        this.updateFromJson(json.post_stream);
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
      .catch((result) => {
        this.errorLoading(result);
        throw new Error(result);
      })
      .finally(() => {
        this.loadingNearPost = null;
      });
  }

  // Fill in a gap of posts before a particular post
  async fillGapBefore(post, gap) {
    const postId = post.id;
    const index = this.stream.indexOf(postId);

    if (index === -1) {
      return;
    }

    // Insert the gap at the appropriate place
    let postIndex = this.posts.indexOf(post);

    const headGap = gap.slice(0, this.topic.chunk_size);
    const tailGap = gap.slice(this.topic.chunk_size);
    this.stream.splice.apply(this.stream, [index, 0].concat(headGap));

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
        this.gaps.before[postId] = tailGap;
      } else {
        delete this.gaps.before[postId];
      }

      post.hasGap = false;
      this.gapExpanded();
    }
  }

  // Fill in a gap of posts after a particular post
  async fillGapAfter(post, gap) {
    const postId = post.id;
    const index = this.stream.indexOf(postId);

    if (index === -1) {
      return;
    }

    this.stream.push(...gap);

    await this.appendMore();
    delete this.gaps.after[postId];
    this.gapExpanded();
  }

  gapExpanded() {
    // resets the reply count in posts-filtered-notice
    // because once a gap has been expanded that count is no longer exact
    if (this.streamFilters?.replies_to_post_number) {
      this.streamFilters.mixedHiddenPosts = true;
    }
  }

  // Appends the next window of posts to the stream. Call it when scrolling downwards.
  async appendMore() {
    // Make sure we can append more posts
    if (!this.canAppendMore) {
      return;
    }

    if (this.isMegaTopic) {
      this.loadingBelow = true;
      this.appendingPlaceholders += this.topic.chunk_size - 1;

      try {
        await this.fetchNextWindow(this.posts.at(-1).post_number, true, (p) => {
          this.appendPost(p);
        });
      } finally {
        this.appendingPlaceholders -= this.topic.chunk_size - 1;
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

  // Prepend the previous window of posts to the stream. Call it when scrolling upwards.
  async prependMore() {
    // Make sure we can append more posts
    if (!this.canPrependMore) {
      return;
    }

    if (this.isMegaTopic) {
      this.loadingAbove = true;

      try {
        await this.fetchNextWindow(this.posts[0].post_number, false, (p) => {
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
  stagePost(post, user) {
    // We can't stage two posts simultaneously
    if (this.stagingPost) {
      return "alreadyStaging";
    }

    this.stagingPost = true;

    this.topic.setProperties({
      posts_count: (this.topic.posts_count || 0) + 1,
      last_posted_at: new Date(),
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

  // Commit the post we staged. Call this after a save succeeds.
  commitPost(post) {
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
  undoPost(post) {
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

  prependPost(post) {
    this._initUserModels(post);
    const stored = this.storePost(post);

    if (stored && !this.posts.includes(stored)) {
      this.posts.unshift(stored);
    }

    return post;
  }

  appendPost(post) {
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

  removePosts(posts) {
    if (isEmpty(posts)) {
      return;
    }

    const postIds = posts.map((p) => p.id);

    removeValuesFromArray(this.stream, postIds);
    removeValuesFromArray(this.posts, posts);
    postIds.forEach((id) => delete this._identityMap[id]);
  }

  removeAllPosts() {
    const posts = Object.values(this._identityMap).filter((p) => p);
    this.removePosts(posts);
  }

  // Returns a post from the identity map if it's been inserted.
  findLoadedPost(id) {
    return this._identityMap[id];
  }

  loadPostByPostNumber(postNumber) {
    const url = `/posts/by_number/${this.topic.id}/${postNumber}`;

    return ajax(url).then((post) => {
      return this.storePost(this.store.createRecord("post", post));
    });
  }

  loadNearestPostToDate(date) {
    const url = `/posts/by-date/${this.topic.id}/${date}`;

    return ajax(url).then((post) => {
      return this.storePost(this.store.createRecord("post", post));
    });
  }

  loadPost(postId) {
    const existing = this._identityMap[postId];

    return ajax(`/posts/${postId}`).then((p) => {
      if (existing) {
        p.cooked = existing.cooked;
      }

      return this.storePost(this.store.createRecord("post", p));
    });
  }

  /* mainly for backwards compatibility with plugins, used in quick messages plugin
   * TODO: remove July 2022
   * */
  triggerNewPostInStream(postId, opts) {
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
  async triggerNewPostsInStream(postIds, opts) {
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
        if (!this._loadingPostIds.includes(postId)) {
          this._loadingPostIds.push(postId);
        }
      });

      this.loadingLastPost = true;

      try {
        const posts = await this.findPostsByIds(this._loadingPostIds, opts);
        this._loadingPostIds = null;

        const ignoredUsers = this.currentUser?.ignored_users;
        posts.forEach((p) => {
          if (ignoredUsers?.includes(p.username)) {
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

  async triggerRecoveredPost(postId) {
    const existing = this._identityMap[postId];

    if (existing) {
      return this.triggerChangedPost(postId, new Date());
    }

    // need to insert into stream
    const p = await ajax(`/posts/${postId}`);
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
      if (post.post_number < this.posts.at(-1).post_number + 5) {
        await this.appendMore();
      }
    }
  }

  triggerDeletedPost(postId) {
    const existing = this._identityMap[postId];

    if (existing && !existing.deleted_at) {
      return ajax(`/posts/${postId}`)
        .then((p) => {
          this.storePost(this.store.createRecord("post", p));
        })
        .catch(() => {
          this.removePosts([existing]);
        });
    }

    return Promise.resolve();
  }

  triggerDestroyedPost(postId) {
    const existing = this._identityMap[postId];
    this.removePosts([existing]);
    return Promise.resolve();
  }

  /**
   * Updates a post in the stream when it has been changed on the server.
   *
   * @param {number} postId - The ID of the post to update
   * @param {string} updatedAt - The timestamp when the post was last updated
   * @param {Object} opts - Additional options for updating the post
   * @param {boolean} [opts.preserveCooked] - Whether to preserve the cooked HTML content
   * @returns {Promise} A promise that resolves when the post has been updated
   */
  async triggerChangedPost(postId, updatedAt, opts = {}) {
    opts ||= {};

    if (!postId) {
      return;
    }

    const existing = this._identityMap[postId];

    // Only fetch and update if the post exists and has a different updated timestamp
    if (existing && existing.updated_at !== updatedAt) {
      // Fetch the latest post data from the server
      const updatedData = await ajax(`/posts/${postId}`);

      // Preserve the existing cooked HTML content if requested
      if (opts.preserveCooked) {
        updatedData.cooked = existing.cooked;
      }

      // Create a new post record with updated data and store it in the identity map.
      // Creating a new record will update the existing one in the map, which will then
      // trigger re-rendering of UI components that use the tracked data that was updated.
      const updatedPost = this.store.createRecord("post", updatedData);

      // Update the post in the post stream's identity map
      this.storePost(updatedPost);
    }
  }

  triggerLikedPost(postId, likesCount, userID, eventType) {
    const resolved = Promise.resolve();

    const post = this.findLoadedPost(postId);
    if (post) {
      post.updateLikeCount(likesCount, userID, eventType);
      this.storePost(post);
    }

    return resolved;
  }

  triggerReadPost(postId, readersCount) {
    const resolved = Promise.resolve();

    resolved.then(() => {
      const post = this.findLoadedPost(postId);
      if (post && readersCount > post.readers_count) {
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

    return Promise.resolve().then(() => {
      const firstPost = this.posts.find((p) => p.post_number === 1);
      return firstPost.id;
    });
  }

  postForPostNumber(postNumber) {
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
  closestPostForPostNumber(postNumber) {
    if (!this.hasPosts) {
      return;
    }

    let closest = null;
    this.posts.forEach((p) => {
      if (!closest) {
        closest = p;
        return;
      }

      if (
        Math.abs(postNumber - p.post_number) <
        Math.abs(closest.post_number - postNumber)
      ) {
        closest = p;
      }
    });

    return closest;
  }

  // Get the index of a post in the stream. (Use this for the topic progress bar.)
  progressIndexOfPost(post) {
    return this.progressIndexOfPostId(post);
  }

  // Get the index in the stream of a post id. (Use this for the topic progress bar.)
  progressIndexOfPostId(post) {
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
  closestPostNumberFor(postNumber) {
    if (!this.hasPosts) {
      return;
    }

    let closest = null;
    this.posts.forEach((p) => {
      if (closest === postNumber) {
        return;
      }
      if (!closest) {
        closest = p.post_number;
      }

      if (
        Math.abs(postNumber - p.post_number) < Math.abs(closest - postNumber)
      ) {
        closest = p.post_number;
      }
    });

    return closest;
  }

  closestDaysAgoFor(postNumber) {
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

  // Find a postId for a postNumber, respecting gaps
  findPostIdForPostNumber(postNumber) {
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

  updateFromJson(postStreamData) {
    this.posts.length = 0;
    this.gaps = null;

    if (postStreamData) {
      // Load posts if present
      postStreamData.posts.forEach((p) =>
        this.appendPost(this.store.createRecord("post", p))
      );
      delete postStreamData.posts;

      // Update our attributes
      postStreamData.gaps = {
        before: new TrackedObject(postStreamData.gaps?.before || {}),
        after: new TrackedObject(postStreamData.gaps?.after || {}),
      };
      this.setProperties(postStreamData);
    }
  }

  /**
    Stores a post in our identity map, and sets up the references it needs to
    find associated objects like the topic. It might return a different reference
    than you supplied if the post has already been loaded.
  **/
  storePost(post) {
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
        this.topic.last_posted_at = post.created_at;
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

  fetchNextWindow(postNumber, asc, callback) {
    let data = {
      post_number: postNumber,
      asc,
      include_suggested: !this.topic.suggested_topics,
    };

    data = deepMerge(data, this.streamFilters);

    return ajax(`/t/${this.topic.id}/posts.json`, { data })
      .then((result) => {
        this._setSuggestedTopics(result);

        const posts = get(result, "post_stream.posts");

        if (posts) {
          posts.forEach((p) => {
            p = this.storePost(this.store.createRecord("post", p));

            if (callback) {
              callback.call(this, p);
            }
          });
        }
      })
      .catch((error) => {
        // If we get a 403 error, refresh the window to prevent continuous retries
        if (error.jqXHR && error.jqXHR.status === 403) {
          window.location.reload();
          return;
        }
      });
  }

  async findPostsByIds(postIds, opts) {
    const unloaded = postIds.filter((p) => !this._identityMap[p]);

    // Load our unloaded posts by id
    await this.loadIntoIdentityMap(unloaded, opts);

    return postIds
      .map((p) => this._identityMap[p])
      .filter((item) => item != null);
  }

  async loadIntoIdentityMap(postIds, opts) {
    if (isEmpty(postIds)) {
      return [];
    }

    const data = {
      post_ids: postIds,
      include_suggested: !this.topic.suggested_topics,
    };

    let headers = {};
    if (opts?.background) {
      headers["Discourse-Background"] = "true";
    }

    try {
      const result = await ajax(`/t/${this.topic.id}/posts.json`, {
        data,
        headers,
      });

      this._setSuggestedTopics(result);
      if (result.user_badges) {
        this.topic.user_badges ??= {};
        Object.assign(this.topic.user_badges, result.user_badges);
      }

      const posts = get(result, "post_stream.posts");

      if (posts) {
        posts.forEach((p) =>
          this.storePost(this.store.createRecord("post", p))
        );
      }
    } catch (error) {
      // If we get a 403 error, refresh the window to prevent continuous retries
      if (error.jqXHR?.status === 403) {
        window.location.reload();
        return;
      }
      throw error;
    }
  }

  backfillExcerpts(streamPosition) {
    this._excerpts ||= [];
    this._excerpts.loadNext = streamPosition;

    if (this._excerpts.loading) {
      return this._excerpts.loading.then(() => {
        if (
          !this._excerpts[this.stream[streamPosition]] &&
          this._excerpts.loadNext === streamPosition
        ) {
          return this.backfillExcerpts(streamPosition);
        }
      });
    }

    let postIds = this.stream.slice(
      Math.max(streamPosition - 20, 0),
      streamPosition + 20
    );

    for (let i = postIds.length - 1; i >= 0; i--) {
      if (this._excerpts[postIds[i]]) {
        postIds.splice(i, 1);
      }
    }

    let data = {
      post_ids: postIds,
    };

    this._excerpts.loading = ajax(`/t/${this.topic.id}/excerpts.json`, {
      data,
    })
      .then((excerpts) => {
        excerpts.forEach((obj) => {
          this._excerpts[obj.post_id] = obj;
        });
      })
      .finally(() => {
        this._excerpts.loading = null;
      });

    return this._excerpts.loading;
  }

  excerpt(streamPosition) {
    if (this.isMegaTopic) {
      return new Promise((resolve) => resolve(""));
    }

    return new Promise((resolve, reject) => {
      const excerpt = this._excerpts?.[this.stream[streamPosition]];

      if (excerpt) {
        resolve(excerpt);
        return;
      }

      this.backfillExcerpts(streamPosition)
        .then(() => {
          resolve(this._excerpts[this.stream[streamPosition]]);
        })
        .catch((e) => reject(e));
    });
  }

  indexOf(post) {
    return this.stream.indexOf(post.id);
  }

  // Handles an error loading a topic based on a HTTP status code. Updates
  // the text to the correct values.
  errorLoading(error) {
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

  _initUserModels(post) {
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

  _setSuggestedTopics(result) {
    if (!result.suggested_topics) {
      return;
    }

    this.topic.setProperties({
      suggested_topics: result.suggested_topics,
      suggested_group_name: result.suggested_group_name,
    });

    if (this.topic.isPrivateMessage) {
      this.pmTopicTrackingState.startTracking();
    }
  }
}
