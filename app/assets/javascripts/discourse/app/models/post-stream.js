import { tracked } from "@glimmer/tracking";
import { get } from "@ember/object";
import { and, equal, not, or } from "@ember/object/computed";
import { schedule } from "@ember/runloop";
import { service } from "@ember/service";
import { isEmpty } from "@ember/utils";
import { TrackedObject } from "@ember-compat/tracked-built-ins";
import { Promise } from "rsvp";
import { ajax } from "discourse/lib/ajax";
import discourseComputed from "discourse/lib/decorators";
import deprecated from "discourse/lib/deprecated";
import { deepMerge } from "discourse/lib/object";
import PostsWithPlaceholders from "discourse/lib/posts-with-placeholders";
import { applyBehaviorTransformer } from "discourse/lib/transformer";
import DiscourseURL from "discourse/lib/url";
import { highlightPost } from "discourse/lib/utilities";
import RestModel from "discourse/models/rest";
import { loadTopicView } from "discourse/models/topic";
import { i18n } from "discourse-i18n";

let _lastEditNotificationClick = null;

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
  @service currentUser;
  @service store;

  @tracked filter;
  @tracked gaps;
  @tracked lastId;
  @tracked loadingNearPost;
  @tracked
  filterRepliesToPostNumber =
    parseInt(this.get("topic.replies_to_post_number"), 10) || false;
  @tracked filterUpwardsPostID = false;
  @tracked loaded = false;
  @tracked loadingAbove = false;
  @tracked loadingBelow = false;
  @tracked loadingFilter = false;
  @tracked stagingPost = false;
  @tracked stream = [];
  @tracked timelineLookup = [];
  @tracked userFilters = [];
  @tracked posts = [];
  @tracked postsWithPlaceholders = PostsWithPlaceholders.create({
    posts: this.posts,
  });

  @or("loadingAbove", "loadingBelow", "loadingFilter", "stagingPost") loading;
  @not("loading") notLoading;
  @equal("filter", "summary") summary;
  @and("notLoading", "hasPosts", "lastPostNotLoaded") canAppendMore;
  @and("notLoading", "hasPosts", "firstPostNotLoaded") canPrependMore;
  @not("firstPostPresent") firstPostNotLoaded;
  @not("loadedAllPosts") lastPostNotLoaded;

  _identityMap = {};

  @discourseComputed(
    "isMegaTopic",
    "stream.length",
    "topic.highest_post_number"
  )
  filteredPostsCount(isMegaTopic, streamLength, topicHighestPostNumber) {
    return isMegaTopic ? topicHighestPostNumber : streamLength;
  }

  @discourseComputed("posts.[]")
  hasPosts() {
    return this.get("posts.length") > 0;
  }

  @discourseComputed("hasPosts", "filteredPostsCount")
  hasLoadedData(hasPosts, filteredPostsCount) {
    return hasPosts && filteredPostsCount > 0;
  }

  @discourseComputed("hasLoadedData", "posts.[]")
  firstPostPresent(hasLoadedData) {
    if (!hasLoadedData) {
      return false;
    }

    return !!this.posts.findBy("post_number", 1);
  }

  @discourseComputed("isMegaTopic", "stream.lastObject", "lastId")
  lastPostId(isMegaTopic, streamLastId, lastId) {
    return isMegaTopic ? lastId : streamLastId;
  }

  @discourseComputed("hasLoadedData", "lastPostId", "posts.@each.id")
  loadedAllPosts(hasLoadedData, lastPostId) {
    if (!hasLoadedData) {
      return false;
    }
    if (lastPostId === -1) {
      return true;
    }

    return !!this.posts.findBy("id", lastPostId);
  }

  /**
    Returns a JS Object of current stream filter options. It should match the query
    params for the stream.
  **/
  @discourseComputed(
    "filter",
    "userFilters.[]",
    "filterRepliesToPostNumber",
    "filterUpwardsPostID"
  )
  streamFilters() {
    const result = {};

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

  @discourseComputed("streamFilters.[]", "topic.posts_count", "posts.length")
  hasNoFilters() {
    return !(
      this.streamFilters &&
      (this.streamFilters?.filter === "summary" ||
        this.streamFilters?.username_filters)
    );
  }

  /**
    Returns the window of posts above the current set in the stream, bound to the top of the stream.
    This is the collection we'll ask for when scrolling upwards.
  **/
  @discourseComputed("posts.[]", "stream.[]")
  previousWindow() {
    if (!this.posts) {
      return [];
    }

    // If we can't find the last post loaded, bail
    const firstPost = this.posts[0];
    if (!firstPost) {
      return [];
    }

    // Find the index of the last post loaded, if not found, bail
    const firstIndex = this.indexOf(firstPost);
    if (firstIndex === -1) {
      return [];
    }

    let startIndex = firstIndex - this.get("topic.chunk_size");
    if (startIndex < 0) {
      startIndex = 0;
    }
    return this.stream.slice(startIndex, firstIndex);
  }

  /**
    Returns the window of posts below the current set in the stream, bound by the bottom of the
    stream. This is the collection we use when scrolling downwards.
  **/
  @discourseComputed("posts.lastObject", "stream.[]")
  nextWindow(lastLoadedPost) {
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
      lastIndex + this.get("topic.chunk_size") + 1
    );
  }

  cancelFilter() {
    this.set("streamFilters.mixedHiddenPosts", false);
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
        DiscourseURL.jumpToPost(this.posts[1].get("post_number"));
      }
    });
  }

  showTopReplies() {
    this.cancelFilter();
    this.set("filter", "summary");
    return this.refreshAndJumpToSecondVisible();
  }

  // Filter the stream to a particular user.
  filterParticipant(username) {
    this.cancelFilter();
    this.userFilters.addObject(username);
    return this.refreshAndJumpToSecondVisible();
  }

  filterReplies(postNumber, postId) {
    this.cancelFilter();
    this.set("filterRepliesToPostNumber", postNumber);

    this.appEvents.trigger("post-stream:filter-replies", {
      topic_id: this.get("topic.id"),
      post_number: postNumber,
      post_id: postId,
    });

    return this.refresh({ refreshInPlace: true }).then(() => {
      const element = document.querySelector(`#post_${postNumber}`);

      // order is important, we need to get the offset before triggering a refresh
      const originalTopOffset = element
        ? element.getBoundingClientRect().top
        : null;

      // TODO (glimmer-post-stream) the Glimmer Post Stream does not listen to this event
      this.appEvents.trigger("post-stream:refresh");

      DiscourseURL.jumpToPost(postNumber, { originalTopOffset });

      schedule("afterRender", () => highlightPost(postNumber));
    });
  }

  filterUpwards(postId) {
    this.cancelFilter();
    this.set("filterUpwardsPostID", postId);

    this.appEvents.trigger("post-stream:filter-upwards", {
      topic_id: this.get("topic.id"),
      post_id: postId,
    });

    return this.refresh({ refreshInPlace: true }).then(() => {
      // TODO (glimmer-post-stream) the Glimmer Post Stream does not listen to this event
      this.appEvents.trigger("post-stream:refresh");

      if (this.posts?.length > 1) {
        const postNumber = this.posts[1].get("post_number");
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
    opts.nearPost = parseInt(opts.nearPost, 10);

    if (opts.cancelFilter) {
      this.cancelFilter();
      delete opts.cancelFilter;
    }

    // Do we already have the post in our list of posts? Jump there.
    if (opts.forceLoad) {
      this.set("loaded", false);
    } else {
      const postWeWant = this.posts.findBy("post_number", opts.nearPost);
      if (postWeWant) {
        return Promise.resolve().then(() => this._checkIfShouldShowRevisions());
      }
    }

    // TODO: if we have all the posts in the filter, don't go to the server for them.
    if (!opts.refreshInPlace) {
      this.set("loadingFilter", true);
    }
    this.set("loadingNearPost", opts.nearPost);

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
        this.set("loadingNearPost", null);
      });
  }

  // Fill in a gap of posts before a particular post
  fillGapBefore(post, gap) {
    const postId = post.id;
    const index = this.stream.indexOf(postId);

    if (index !== -1) {
      // Insert the gap at the appropriate place
      let postIndex = this.posts.indexOf(post);
      let headGap = gap.slice(0, this.topic.chunk_size);
      let tailGap = gap.slice(this.topic.chunk_size);
      this.stream.splice.apply(this.stream, [index, 0].concat(headGap));

      if (postIndex !== -1) {
        return this.findPostsByIds(headGap).then((posts) => {
          posts.forEach((p) => {
            this._initUserModels(p);
            const stored = this.storePost(p);

            if (!this.posts.includes(stored)) {
              this.postsWithPlaceholders.insertPost(postIndex, () => {
                this.posts.insertAt(postIndex, stored);
              });

              postIndex++;
            }
          });

          if (tailGap.length > 0) {
            this.get("gaps.before")[postId] = tailGap;
          } else {
            delete this.get("gaps.before")[postId];
          }

          post.set("hasGap", false);
          this.gapExpanded();
        });
      }
    }

    return Promise.resolve();
  }

  // Fill in a gap of posts after a particular post
  fillGapAfter(post, gap) {
    const postId = post.id;
    const index = this.stream.indexOf(postId);

    if (index !== -1) {
      this.stream.pushObjects(gap);
      return this.appendMore().then(() => {
        delete this.get("gaps.after")[postId];
        this.gapExpanded();
      });
    }

    return Promise.resolve();
  }

  gapExpanded() {
    // TODO (glimmer-post-stream) the Glimmer Post Stream does not listen to this event
    this.appEvents.trigger("post-stream:refresh");

    // resets the reply count in posts-filtered-notice
    // because once a gap has been expanded that count is no longer exact
    if (this.streamFilters?.replies_to_post_number) {
      this.set("streamFilters.mixedHiddenPosts", true);
    }
  }

  // Appends the next window of posts to the stream. Call it when scrolling downwards.
  appendMore() {
    // Make sure we can append more posts
    if (!this.canAppendMore) {
      return Promise.resolve();
    }

    const postsWithPlaceholders = this.postsWithPlaceholders;

    if (this.isMegaTopic) {
      this.set("loadingBelow", true);

      const fakePostIds = [
        ...Array(this.get("topic.chunk_size") - 1).keys(),
      ].map((i) => -i - 1);
      postsWithPlaceholders.appending(fakePostIds);

      return this.fetchNextWindow(
        this.get("posts.lastObject.post_number"),
        true,
        (p) => {
          this.appendPost(p);
        }
      ).finally(() => {
        postsWithPlaceholders.finishedAppending(fakePostIds);
        this.set("loadingBelow", false);
      });
    } else {
      const postIds = this.nextWindow;
      if (isEmpty(postIds)) {
        return Promise.resolve();
      }
      this.set("loadingBelow", true);
      postsWithPlaceholders.appending(postIds);

      return this.findPostsByIds(postIds)
        .then((posts) => {
          posts.forEach((p) => this.appendPost(p));
          return posts;
        })
        .finally(() => {
          postsWithPlaceholders.finishedAppending(postIds);
          this.set("loadingBelow", false);
        });
    }
  }

  // Prepend the previous window of posts to the stream. Call it when scrolling upwards.
  prependMore() {
    // Make sure we can append more posts
    if (!this.canPrependMore) {
      return Promise.resolve();
    }

    if (this.isMegaTopic) {
      this.set("loadingAbove", true);
      let prependedIds = [];

      return this.fetchNextWindow(
        this.get("posts.firstObject.post_number"),
        false,
        (p) => {
          this.prependPost(p);
          prependedIds.push(p.get("id"));
        }
      ).finally(() => {
        this.postsWithPlaceholders.finishedPrepending(prependedIds);
        this.set("loadingAbove", false);
      });
    } else {
      const postIds = this.previousWindow;
      if (isEmpty(postIds)) {
        return Promise.resolve();
      }
      this.set("loadingAbove", true);

      return this.findPostsByIds(postIds.reverse())
        .then((posts) => {
          posts.forEach((p) => this.prependPost(p));
        })
        .finally(() => {
          this.postsWithPlaceholders.finishedPrepending(postIds);
          this.set("loadingAbove", false);
        });
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

    this.set("stagingPost", true);

    this.topic.setProperties({
      posts_count: (this.topic.get("posts_count") || 0) + 1,
      last_posted_at: new Date(),
      "details.last_poster": user,
      highest_post_number: (this.topic.get("highest_post_number") || 0) + 1,
    });

    post.setProperties({
      post_number: this.topic.get("highest_post_number"),
      topic: this.topic,
      created_at: new Date(),
      id: -1,
    });

    // If we're at the end of the stream, add the post
    if (this.loadedAllPosts) {
      this.appendPost(post);
      this.stream.addObject(post.id);
      return "staged";
    }

    return "offScreen";
  }

  // Commit the post we staged. Call this after a save succeeds.
  commitPost(post) {
    if (this.get("topic.id") === post.get("topic_id")) {
      if (this.loadedAllPosts) {
        this.appendPost(post);
        this.stream.addObject(post.id);
      }
    }

    this.stream.removeObject(-1);
    this._identityMap[-1] = null;
    this.set("stagingPost", false);
  }

  /**
    Undo a post we've staged in the stream. Remove it from being rendered and revert the
    state we changed.
  **/
  undoPost(post) {
    this.stream.removeObject(-1);
    this.postsWithPlaceholders.removePost(() => this.posts.removeObject(post));
    this._identityMap[-1] = null;

    this.set("stagingPost", false);

    this.topic.setProperties({
      highest_post_number: (this.topic.get("highest_post_number") || 0) - 1,
      posts_count: (this.topic.get("posts_count") || 0) - 1,
    });

    // TODO unfudge reply count on parent post
  }

  prependPost(post) {
    this._initUserModels(post);
    const stored = this.storePost(post);

    if (stored) {
      this.posts.unshiftObject(stored);
    }

    return post;
  }

  appendPost(post) {
    this._initUserModels(post);
    const stored = this.storePost(post);

    if (stored) {
      if (!this.posts.includes(stored)) {
        if (!this.loadingBelow) {
          this.postsWithPlaceholders.appendPost(() =>
            this.posts.pushObject(stored)
          );
        } else {
          this.posts.pushObject(stored);
        }
      }

      if (stored.get("id") !== -1) {
        this.set("lastAppended", stored);
      }
    }

    return post;
  }

  removePosts(posts) {
    if (isEmpty(posts)) {
      return;
    }

    this.postsWithPlaceholders.refreshAll(() => {
      const postIds = posts.map((p) => p.get("id"));

      this.stream.removeObjects(postIds);
      this.posts.removeObjects(posts);
      postIds.forEach((id) => delete this._identityMap[id]);
    });
  }

  // Returns a post from the identity map if it's been inserted.
  findLoadedPost(id) {
    return this._identityMap[id];
  }

  loadPostByPostNumber(postNumber) {
    const url = `/posts/by_number/${this.get("topic.id")}/${postNumber}`;

    return ajax(url).then((post) => {
      return this.storePost(this.store.createRecord("post", post));
    });
  }

  loadNearestPostToDate(date) {
    const url = `/posts/by-date/${this.get("topic.id")}/${date}`;

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
  triggerNewPostsInStream(postIds, opts) {
    const resolved = Promise.resolve();

    if (!postIds || postIds.length === 0) {
      return resolved;
    }

    // We only trigger if there are no filters active
    if (!this.hasNoFilters) {
      return resolved;
    }

    this._loadingPostIds = this._loadingPostIds || [];

    let missingIds = [];

    postIds.forEach((postId) => {
      if (postId && !this.stream.includes(postId)) {
        missingIds.push(postId);
      }
    });

    if (missingIds.length === 0) {
      return resolved;
    }

    if (this.loadedAllPosts) {
      missingIds.forEach((postId) => {
        if (!this._loadingPostIds.includes(postId)) {
          this._loadingPostIds.push(postId);
        }
      });

      this.set("loadingLastPost", true);

      return this.findPostsByIds(this._loadingPostIds, opts)
        .then((posts) => {
          this._loadingPostIds = null;
          const ignoredUsers = this.currentUser?.ignored_users;

          posts.forEach((p) => {
            if (ignoredUsers?.includes(p.username)) {
              this.stream.removeObject(p.id);
              return;
            }

            this.stream.addObject(p.id);
            this.appendPost(p);
          });
        })
        .finally(() => {
          this.set("loadingLastPost", false);
        });
    } else {
      missingIds.forEach((postId) => this.stream.addObject(postId));
    }

    return resolved;
  }

  triggerRecoveredPost(postId) {
    const existing = this._identityMap[postId];

    if (existing) {
      return this.triggerChangedPost(postId, new Date());
    } else {
      // need to insert into stream
      return ajax(`/posts/${postId}`).then((p) => {
        const post = this.store.createRecord("post", p);
        this.storePost(post);

        // we need to zip this into the stream
        let index = 0;
        this.stream.forEach((pid) => {
          if (pid < p.id) {
            index += 1;
          }
        });

        this.stream.insertAt(index, p.id);

        index = 0;
        this.posts.forEach((_post) => {
          if (_post.id < p.id) {
            index += 1;
          }
        });

        if (index < this.posts.length) {
          this.postsWithPlaceholders.refreshAll(() => {
            this.posts.insertAt(index, post);
          });
        } else {
          if (post.post_number < this.posts.at(-1).post_number + 5) {
            this.appendMore();
          }
        }
      });
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
        post.set("readers_count", readersCount);
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
      const firstPost = this.posts.findBy("post_number", 1);
      return firstPost.id;
    });
  }

  postForPostNumber(postNumber) {
    if (!this.hasPosts) {
      return;
    }

    return this.posts.find((p) => {
      return p.get("post_number") === postNumber;
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
        Math.abs(postNumber - p.get("post_number")) <
        Math.abs(closest.get("post_number") - postNumber)
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
      return post.get("post_number");
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
        closest = p.get("post_number");
      }

      if (
        Math.abs(postNumber - p.get("post_number")) <
        Math.abs(closest - postNumber)
      ) {
        closest = p.get("post_number");
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
    const beforeLookup = this.get("gaps.before");

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
    this.postsWithPlaceholders.clear(() => this.posts.clear());

    this.set("gaps", null);
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

    if (post.id) {
      const existing = this._identityMap[post.id];

      // Update the `highest_post_number` if this post is higher.
      const postNumber = post.get("post_number");
      if (
        postNumber &&
        postNumber > (this.get("topic.highest_post_number") || 0)
      ) {
        this.set("topic.highest_post_number", postNumber);
        this.set("topic.last_posted_at", post.get("created_at"));
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
      include_suggested: !this.get("topic.suggested_topics"),
    };

    data = deepMerge(data, this.streamFilters);

    const url = `/t/${this.get("topic.id")}/posts.json`;
    return ajax(url, { data }).then((result) => {
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
    });
  }

  findPostsByIds(postIds, opts) {
    const unloaded = postIds.filter((p) => !this._identityMap[p]);

    // Load our unloaded posts by id
    return this.loadIntoIdentityMap(unloaded, opts).then(() => {
      return postIds.map((p) => this._identityMap[p]).compact();
    });
  }

  loadIntoIdentityMap(postIds, opts) {
    if (isEmpty(postIds)) {
      return Promise.resolve([]);
    }

    const url = `/t/${this.get("topic.id")}/posts.json`;
    const data = {
      post_ids: postIds,
      include_suggested: !this.get("topic.suggested_topics"),
    };

    let headers = {};
    if (opts?.background) {
      headers["Discourse-Background"] = "true";
    }

    return ajax(url, {
      data,
      headers,
    }).then((result) => {
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
    });
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

    this._excerpts.loading = ajax(`/t/${this.get("topic.id")}/excerpts.json`, {
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
    return new Promise((resolve, reject) => {
      let excerpt =
        this._excerpts && this._excerpts[this.stream[streamPosition]];

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
        this.set("loadingFilter", false);
        this.topic.set("errorLoading", true);

        if (!error.jqXHR) {
          throw error;
        }

        const json = error.jqXHR.responseJSON;
        if (json && json.extras && json.extras.html) {
          this.topic.set("errorTitle", json.extras.title);
          this.topic.set("errorHtml", json.extras.html);
        } else {
          this.topic.set(
            "errorMessage",
            i18n("topic.server_error.description")
          );
          this.topic.set("noRetry", error.jqXHR.status === 403);
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
    const postsNumbers = this.posts.mapBy("post_number");

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
