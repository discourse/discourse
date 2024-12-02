import Controller from "@ember/controller";
import EmberObject, { action } from "@ember/object";
import { alias, and, not, or } from "@ember/object/computed";
import { next, schedule } from "@ember/runloop";
import { service } from "@ember/service";
import { isEmpty, isPresent } from "@ember/utils";
import { observes } from "@ember-decorators/object";
import { Promise } from "rsvp";
import {
  CLOSE_INITIATED_BY_BUTTON,
  CLOSE_INITIATED_BY_ESC,
} from "discourse/components/d-modal";
import BookmarkModal from "discourse/components/modal/bookmark";
import ChangePostNoticeModal from "discourse/components/modal/change-post-notice";
import ConvertToPublicTopicModal from "discourse/components/modal/convert-to-public-topic";
import DeleteTopicConfirmModal from "discourse/components/modal/delete-topic-confirm";
import JumpToPost from "discourse/components/modal/jump-to-post";
import { MIN_POSTS_COUNT } from "discourse/components/topic-map/topic-map-summary";
import { spinnerHTML } from "discourse/helpers/loading-spinner";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { BookmarkFormData } from "discourse/lib/bookmark-form-data";
import { resetCachedTopicList } from "discourse/lib/cached-topic-list";
import { wantsNewWindow } from "discourse/lib/intercept-click";
import { buildQuote } from "discourse/lib/quote";
import QuoteState from "discourse/lib/quote-state";
import { extractLinkMeta } from "discourse/lib/render-topic-featured-link";
import DiscourseURL, { userPath } from "discourse/lib/url";
import { escapeExpression } from "discourse/lib/utilities";
import { bufferedProperty } from "discourse/mixins/buffered-content";
import Bookmark, { AUTO_DELETE_PREFERENCES } from "discourse/models/bookmark";
import Category from "discourse/models/category";
import Composer from "discourse/models/composer";
import Post from "discourse/models/post";
import Topic from "discourse/models/topic";
import TopicTimer from "discourse/models/topic-timer";
import { isTesting } from "discourse-common/config/environment";
import discourseLater from "discourse-common/lib/later";
import { deepMerge } from "discourse-common/lib/object";
import discourseComputed, { bind } from "discourse-common/utils/decorators";
import { i18n } from "discourse-i18n";
let customPostMessageCallbacks = {};

const RETRIES_ON_RATE_LIMIT = 4;
const MIN_BOTTOM_MAP_WORD_COUNT = 200;

export function resetCustomPostMessageCallbacks() {
  customPostMessageCallbacks = {};
}

export function registerCustomPostMessageCallback(type, callback) {
  if (customPostMessageCallbacks[type]) {
    throw new Error(`Error ${type} is an already registered post message!`);
  }

  customPostMessageCallbacks[type] = callback;
}

export default class TopicController extends Controller.extend(
  bufferedProperty("model")
) {
  @service composer;
  @service dialog;
  @service documentTitle;
  @service screenTrack;
  @service modal;
  @service currentUser;
  @service router;
  @service siteSettings;
  @service site;
  @service appEvents;

  queryParams = ["filter", "username_filters", "replies_to_post_number"];

  @and("canEditTopicFeaturedLink", "buffered.featured_link")
  canRemoveTopicFeaturedLink;
  @not("model.isPrivateMessage") showCategoryChooser;
  @or("model.errorHtml", "model.errorMessage") hasError;
  @not("hasError") noErrorYet;
  @alias("site.categoriesList") categories;
  @alias("selectedPostIds.length") selectedPostsCount;
  @alias("selectedAllPosts") canDeselectAll;
  @or("model.postStream.loadedAllPosts", "model.postStream.loadingLastPost")
  loadedAllPosts;

  multiSelect = false;
  selectedPostIds = [];
  editingTopic = false;
  enteredAt = null;
  enteredIndex = null;
  retrying = false;
  userTriggeredProgress = null;
  hasScrolled = null;
  username_filters = null;
  replies_to_post_number = null;
  filter = null;
  quoteState = new QuoteState();
  currentPostId = null;
  userLastReadPostNumber = null;
  highestPostNumber = null;
  _progressIndex = null;
  _retryInProgress = false;
  _retryRateLimited = false;
  _newPostsInStream = [];

  init() {
    super.init(...arguments);

    this.appEvents.on("post:show-revision", this, "_showRevision");
    this.appEvents.on("post:created", this, () => {
      this._removeDeleteOnOwnerReplyBookmarks();
      this.appEvents.trigger("post-stream:refresh", { force: true });
    });
  }

  willDestroy() {
    super.willDestroy(...arguments);
    this.appEvents.off("post:show-revision", this, "_showRevision");
  }

  updateQueryParams() {
    const filters = this.get("model.postStream.streamFilters");

    if (Object.keys(filters).length > 0) {
      this.setProperties(filters);
    } else {
      this.setProperties({
        username_filters: null,
        filter: null,
        replies_to_post_number: null,
      });
    }
  }

  @observes("model.title", "category")
  _titleChanged() {
    const title = this.get("model.title");
    if (!isEmpty(title)) {
      // force update lazily loaded titles
      this.send("refreshTitle");
    }
  }

  @discourseComputed("model.postStream.loaded", "model.is_shared_draft")
  showSharedDraftControls(loaded, isSharedDraft) {
    return loaded && isSharedDraft;
  }

  @discourseComputed("site.mobileView", "model.posts_count")
  showSelectedPostsAtBottom(mobileView, postsCount) {
    return mobileView && postsCount > 3;
  }

  @discourseComputed(
    "model.postStream.posts",
    "model.postStream.postsWithPlaceholders"
  )
  postsToRender(posts, postsWithPlaceholders) {
    return this.capabilities.isAndroid ? posts : postsWithPlaceholders;
  }

  @discourseComputed("model.postStream.loadingFilter")
  androidLoading(loading) {
    return this.capabilities.isAndroid && loading;
  }

  @discourseComputed("model")
  pmPath(topic) {
    return this.currentUser && this.currentUser.pmPath(topic);
  }

  _showRevision(postNumber, revision) {
    const post = this.model.get("postStream").postForPostNumber(postNumber);

    if (post && post.version > 1 && post.can_view_edit_history) {
      schedule("afterRender", () => this.send("showHistory", post, revision));
    }
  }

  gotoInbox(name) {
    let url = userPath(`${this.get("currentUser.username_lower")}/messages`);

    if (name) {
      url = `${url}/group/${name}`;
    }

    DiscourseURL.routeTo(url);
  }

  @discourseComputed
  selectedQuery() {
    return (post) => this.postSelected(post);
  }

  @discourseComputed("model.isPrivateMessage", "model.category.id")
  canEditTopicFeaturedLink(isPrivateMessage, categoryId) {
    if (this.currentUser && this.currentUser.trust_level === 0) {
      return false;
    }

    if (!this.siteSettings.topic_featured_link_enabled || isPrivateMessage) {
      return false;
    }

    const categoryIds = this.site.get(
      "topic_featured_link_allowed_category_ids"
    );
    return (
      categoryIds === undefined ||
      !categoryIds.length ||
      categoryIds.includes(categoryId)
    );
  }

  @discourseComputed("model")
  featuredLinkDomain(topic) {
    return extractLinkMeta(topic).domain;
  }

  @discourseComputed("model.isPrivateMessage")
  canEditTags(isPrivateMessage) {
    return (
      this.site.get("can_tag_topics") &&
      (!isPrivateMessage || this.site.get("can_tag_pms"))
    );
  }

  @discourseComputed("currentUser.can_send_private_messages")
  canSendPms() {
    return this.currentUser?.can_send_private_messages;
  }

  @discourseComputed("buffered.category_id")
  minimumRequiredTags(categoryId) {
    return Category.findById(categoryId)?.minimumRequiredTags || 0;
  }

  @discourseComputed(
    "model.postStream.posts",
    "model.word_count",
    "model.postStream.loadingFilter"
  )
  showBottomTopicMap(posts, wordCount, loading) {
    // filter out small posts, because they're short
    const postsCount =
      posts?.filter((post) => post.post_type !== 3).length || 0;

    const minWordCount = isTesting
      ? true
      : wordCount > MIN_BOTTOM_MAP_WORD_COUNT;

    return (
      this.siteSettings.show_bottom_topic_map &&
      !loading &&
      postsCount > MIN_POSTS_COUNT &&
      minWordCount
    );
  }

  _removeDeleteOnOwnerReplyBookmarks() {
    // the user has already navigated away from the topic. the PostCreator
    // in rails already handles deleting the bookmarks that need to be
    // based on auto_delete_preference; this is mainly used to clean up
    // the in-memory post stream and topic model
    if (!this.model) {
      return;
    }

    const posts = this.get("model.postStream.posts");
    if (posts) {
      posts
        .filter(
          (post) =>
            post.bookmarked &&
            post.bookmark_auto_delete_preference ===
              AUTO_DELETE_PREFERENCES.ON_OWNER_REPLY
        )
        .forEach((post) => {
          post.clearBookmark();
          this.model.removeBookmark(post.bookmark_id);
        });
    }
    const forTopicBookmark = this.model.bookmarks.findBy(
      "bookmarkable_type",
      "Topic"
    );
    if (
      forTopicBookmark?.auto_delete_preference ===
      AUTO_DELETE_PREFERENCES.ON_OWNER_REPLY
    ) {
      this.model.removeBookmark(forTopicBookmark.id);
    }
  }

  _forceRefreshPostStream() {
    this.appEvents.trigger("post-stream:refresh", { force: true });
  }

  _updateSelectedPostIds(postIds) {
    const smallActionsPostIds = this._smallActionPostIds();
    this.selectedPostIds.pushObjects(
      postIds.filter((postId) => !smallActionsPostIds.has(postId))
    );
    this.set("selectedPostIds", [...new Set(this.selectedPostIds)]);
    this._forceRefreshPostStream();
  }

  _smallActionPostIds() {
    const smallActionsPostIds = new Set();
    const posts = this.get("model.postStream.posts");
    if (posts && this.site) {
      const smallAction = this.site.get("post_types.small_action");
      const whisper = this.site.get("post_types.whisper");
      posts.forEach((post) => {
        if (
          post.post_type === smallAction ||
          (!post.cooked && post.post_type === whisper)
        ) {
          smallActionsPostIds.add(post.id);
        }
      });
    }
    return smallActionsPostIds;
  }

  _loadPostIds(post) {
    if (this.loadingPostIds) {
      return;
    }

    const postStream = this.get("model.postStream");
    const url = `/t/${this.get("model.id")}/post_ids.json`;

    this.set("loadingPostIds", true);

    return ajax(url, {
      data: deepMerge(
        { post_number: post.get("post_number") },
        postStream.get("streamFilters")
      ),
    })
      .then((result) => {
        result.post_ids.pushObject(post.get("id"));
        this._updateSelectedPostIds(result.post_ids);
      })
      .finally(() => {
        this.set("loadingPostIds", false);
      });
  }

  @action
  editTopic(event) {
    event?.preventDefault();
    if (this.get("model.details.can_edit")) {
      this.set("editingTopic", true);
    }
  }

  @action
  jumpTop(event) {
    if (event && wantsNewWindow(event)) {
      return;
    }

    event?.preventDefault();
    DiscourseURL.routeTo(this.get("model.firstPostUrl"), {
      skipIfOnScreen: false,
      keepFilter: true,
    });
  }

  @action
  removeFeaturedLink(event) {
    event?.preventDefault();
    this.set("buffered.featured_link", null);
  }

  @action
  selectAll(event) {
    event?.preventDefault();
    const smallActionsPostIds = this._smallActionPostIds();
    this.set("selectedPostIds", [
      ...this.get("model.postStream.stream").filter(
        (postId) => !smallActionsPostIds.has(postId)
      ),
    ]);
    this._forceRefreshPostStream();
  }

  @action
  deselectAll(event) {
    event?.preventDefault();
    this.set("selectedPostIds", []);
    this._forceRefreshPostStream();
  }

  @action
  toggleMultiSelect(event) {
    event?.preventDefault();
    this.toggleProperty("multiSelect");
    this._forceRefreshPostStream();
  }

  @action
  topicCategoryChanged(categoryId) {
    this.set("buffered.category_id", categoryId);
  }

  @action
  topicTagsChanged(value) {
    this.set("buffered.tags", value);
  }

  @action
  deletePending(pending) {
    return ajax(`/review/${pending.id}`, { type: "DELETE" })
      .then(() => {
        this.get("model.pending_posts").removeObject(pending);
      })
      .catch(popupAjaxError);
  }

  @action
  showPostFlags(post) {
    return this.send("showFlags", post);
  }

  @action
  openFeatureTopic() {
    this.send("showFeatureTopic");
  }

  @action
  selectText() {
    const { postId, buffer, opts } = this.quoteState;
    const loadedPost = this.get("model.postStream").findLoadedPost(postId);
    const promise = loadedPost
      ? Promise.resolve(loadedPost)
      : this.get("model.postStream").loadPost(postId);

    return promise.then((post) => {
      const composer = this.composer;
      const viewOpen = composer.get("model.viewOpen");

      // If we can't create a post, delegate to reply as new topic
      if (!viewOpen && !this.get("model.details.can_create_post")) {
        this.send("replyAsNewTopic", post);
        return;
      }

      const composerOpts = {
        action: Composer.REPLY,
        draftSequence: post.get("topic.draft_sequence"),
        draftKey: post.get("topic.draft_key"),
      };

      if (post.get("post_number") === 1) {
        composerOpts.topic = post.get("topic");
      } else {
        composerOpts.post = post;
      }

      // If the composer is associated with a different post, we don't change it.
      const composerPost = composer.get("model.post");
      if (composerPost && composerPost.get("id") !== this.get("post.id")) {
        composerOpts.post = composerPost;
      }

      const quotedText = buildQuote(post, buffer, opts);
      composerOpts.quote = quotedText;

      if (composer.get("model.viewOpen")) {
        this.appEvents.trigger("composer:insert-block", quotedText);
      } else if (composer.get("model.viewDraft")) {
        const model = composer.get("model");
        model.set("reply", model.get("reply") + "\n" + quotedText);
        composer.openIfDraft();
      } else {
        composer.open(composerOpts);
      }
    });
  }

  @action
  fillGapBefore(args) {
    return this.get("model.postStream").fillGapBefore(args.post, args.gap);
  }

  @action
  fillGapAfter(args) {
    return this.get("model.postStream").fillGapAfter(args.post, args.gap);
  }

  @action
  currentPostChanged(event) {
    const { post } = event;
    if (!post) {
      return;
    }

    this.set("currentPostId", post.id);
    const postNumber = post.get("post_number");
    const topic = this.model;
    topic.set("currentPost", postNumber);
    if (postNumber > (topic.get("last_read_post_number") || 0)) {
      topic.set("last_read_post_id", post.get("id"));
      topic.set("last_read_post_number", postNumber);
    }

    this.send("postChangedRoute", postNumber);
    this._progressIndex = topic.get("postStream").progressIndexOfPost(post);

    this.appEvents.trigger("topic:current-post-changed", { post });
  }

  @action
  currentPostScrolled(event) {
    const total = this.get("model.postStream.filteredPostsCount");
    const percent = parseFloat(this._progressIndex + event.percent - 1) / total;
    this.appEvents.trigger("topic:current-post-scrolled", {
      postIndex: this._progressIndex,
      percent: Math.max(Math.min(percent, 1.0), 0.0),
    });
  }

  // Called when the topmost visible post on the page changes.
  @action
  topVisibleChanged(event) {
    const { post, refresh } = event;
    if (!post) {
      return;
    }

    const postStream = this.get("model.postStream");
    const firstLoadedPost = postStream.get("posts.firstObject");

    if (post.get && post.get("post_number") === 1) {
      return;
    }

    if (firstLoadedPost && firstLoadedPost === post) {
      postStream.prependMore().then(() => refresh());
    }
  }

  // Called the bottommost visible post on the page changes.
  @action
  bottomVisibleChanged(event) {
    const { post, refresh } = event;

    const postStream = this.get("model.postStream");
    const lastLoadedPost = postStream.get("posts.lastObject");

    if (
      lastLoadedPost &&
      lastLoadedPost === post &&
      postStream.get("canAppendMore")
    ) {
      postStream.appendMore().then(() => refresh());
      // show loading stuff
      refresh();
    }
  }

  @action
  showTopReplies() {
    return this.get("model.postStream")
      .showTopReplies()
      .then(() => {
        this.updateQueryParams();
      });
  }

  @action
  cancelFilter(nearestPost = null) {
    const postStream = this.get("model.postStream");

    if (!nearestPost) {
      const loadedPost = postStream.findLoadedPost(this.currentPostId);
      if (loadedPost) {
        nearestPost = loadedPost.post_number;
      } else {
        postStream.findPostsByIds([this.currentPostId]).then((arr) => {
          nearestPost = arr[0].post_number;
        });
      }
    }

    postStream.cancelFilter();
    postStream
      .refresh({
        nearPost: nearestPost,
        forceLoad: true,
      })
      .then(() => {
        DiscourseURL.routeTo(this.model.urlForPostNumber(nearestPost));
        this.updateQueryParams();
      });
  }

  @action
  removeAllowedUser(user) {
    return this.get("model.details")
      .removeAllowedUser(user)
      .then(() => {
        if (this.currentUser.id === user.id) {
          this.router.transitionTo("userPrivateMessages", user);
        }
      });
  }

  @action
  removeAllowedGroup(group) {
    return this.get("model.details").removeAllowedGroup(group);
  }

  // Archive a PM (as opposed to archiving a topic)
  @action
  toggleArchiveMessage() {
    const topic = this.model;

    if (!topic || topic.get("archiving") || !topic.isPrivateMessage) {
      return;
    }

    const backToInbox = () => {
      resetCachedTopicList(this.session);
      this.gotoInbox(topic.get("inboxGroupName"));
    };

    if (topic.get("message_archived")) {
      topic.moveToInbox().then(backToInbox);
    } else {
      topic.archiveMessage().then(backToInbox);
    }
  }

  @action
  deferTopic() {
    const { screenTrack, currentUser } = this;
    const topic = this.model;

    screenTrack.reset();
    screenTrack.stop();
    const goToPath = topic.get("isPrivateMessage")
      ? currentUser.pmPath(topic)
      : "/";
    ajax("/t/" + topic.get("id") + "/timings.json?last=1", { type: "DELETE" })
      .then(() => {
        const highestSeenByTopic = this.session.get("highestSeenByTopic");
        highestSeenByTopic[topic.get("id")] = null;
        DiscourseURL.routeTo(goToPath);
      })
      .catch(popupAjaxError);
  }

  @action
  editFirstPost() {
    this.model
      .firstPost()
      .then((firstPost) => this.send("editPost", firstPost));
  }

  // Post related methods
  @action
  replyToPost(post) {
    const composerController = this.composer;
    const topic = post ? post.get("topic") : this.model;
    const quoteState = this.quoteState;
    const postStream = this.get("model.postStream");

    this.appEvents.trigger("page:compose-reply", topic);

    if (!postStream || !topic || !topic.get("details.can_create_post")) {
      return;
    }

    const quotedPost = postStream.findLoadedPost(quoteState.postId);
    const quotedText = buildQuote(
      quotedPost,
      quoteState.buffer,
      quoteState.opts
    );

    quoteState.clear();

    if (
      composerController.get("model.topic.id") === topic.get("id") &&
      composerController.get("model.action") === Composer.REPLY &&
      post?.get("post_number") !== 1
    ) {
      composerController.set("model.post", post);
      composerController.set("model.composeState", Composer.OPEN);
      this.appEvents.trigger("composer:insert-block", quotedText.trim());
    } else {
      const opts = {
        action: Composer.REPLY,
        draftKey: topic.get("draft_key"),
        draftSequence: topic.get("draft_sequence"),
      };

      if (quotedText) {
        opts.quote = quotedText;
      }

      if (post && post.get("post_number") !== 1) {
        opts.post = post;
      } else {
        opts.topic = topic;
      }

      composerController.open(opts);
    }
    return false;
  }

  @action
  recoverPost(post) {
    post.get("post_number") === 1 ? this.recoverTopic() : post.recover();
  }

  @action
  deletePost(post, opts) {
    if (post.get("post_number") === 1) {
      return this.deleteTopic(opts);
    } else if (
      (!opts?.force_destroy && !post.can_delete) ||
      (opts?.force_destroy && !post.can_permanently_delete)
    ) {
      return false;
    }

    const user = this.currentUser;
    const refresh = () => this.appEvents.trigger("post-stream:refresh");
    const hasReplies = post.get("reply_count") > 0;
    const loadedPosts = this.get("model.postStream.posts");

    if (user.get("staff") && hasReplies) {
      ajax(`/posts/${post.id}/reply-ids.json`).then((replies) => {
        if (replies.length === 0) {
          return post
            .destroy(user, opts)
            .then(refresh)
            .catch((error) => {
              popupAjaxError(error);
              post.undoDeleteState();
            });
        }

        const buttons = [];

        const directReplyIds = replies
          .filter((r) => r.level === 1)
          .map((r) => r.id);

        buttons.push({
          label: i18n("post.controls.delete_replies.direct_replies", {
            count: directReplyIds.length,
          }),
          class: "btn-primary",
          action: () => {
            loadedPosts.forEach(
              (p) =>
                (p === post || directReplyIds.includes(p.id)) &&
                p.setDeletedState(user)
            );
            Post.deleteMany([post.id, ...directReplyIds])
              .then(refresh)
              .catch(popupAjaxError);
          },
        });

        if (replies.some((r) => r.level > 1)) {
          buttons.push({
            label: i18n("post.controls.delete_replies.all_replies", {
              count: replies.length,
            }),
            action: () => {
              loadedPosts.forEach(
                (p) =>
                  (p === post || replies.some((r) => r.id === p.id)) &&
                  p.setDeletedState(user)
              );
              Post.deleteMany([post.id, ...replies.map((r) => r.id)])
                .then(refresh)
                .catch(popupAjaxError);
            },
          });
        }

        buttons.push({
          label: i18n("post.controls.delete_replies.just_the_post"),
          action: () => {
            post
              .destroy(user, opts)
              .then(refresh)
              .catch((error) => {
                popupAjaxError(error);
                post.undoDeleteState();
              });
          },
        });

        buttons.push({
          label: i18n("cancel"),
          class: "btn-flat",
        });

        this.dialog.alert({
          title: i18n("post.controls.delete_replies.confirm"),
          buttons,
        });
      });
    } else {
      return post
        .destroy(user, opts)
        .then(refresh)
        .catch((error) => {
          popupAjaxError(error);
          post.undoDeleteState();
        });
    }
  }

  @action
  deletePostWithConfirmation(post, opts) {
    this.dialog.yesNoConfirm({
      message: i18n("post.confirm_delete"),
      didConfirm: () => this.send("deletePost", post, opts),
    });
  }

  @action
  permanentlyDeletePost(post) {
    return this.dialog.yesNoConfirm({
      message: i18n("post.controls.permanently_delete_confirmation"),
      didConfirm: () => {
        this.send("deletePost", post, { force_destroy: true });
      },
    });
  }

  @action
  editPost(post) {
    if (!this.currentUser) {
      return this.dialog.alert(i18n("post.controls.edit_anonymous"));
    } else if (!post.can_edit) {
      return false;
    }

    const topic = this.model;

    let editingSharedDraft = false;
    let draftsCategoryId = this.get("site.shared_drafts_category_id");
    if (draftsCategoryId && draftsCategoryId === topic.get("category.id")) {
      editingSharedDraft = post.get("firstPost");
    }

    const opts = {
      post,
      action: editingSharedDraft ? Composer.EDIT_SHARED_DRAFT : Composer.EDIT,
      draftKey: post.get("topic.draft_key"),
      draftSequence: post.get("topic.draft_sequence"),
    };

    if (editingSharedDraft) {
      opts.destinationCategoryId = topic.get("destination_category_id");
    }

    const { composer } = this;
    const composerModel = composer.get("model");
    const editingSamePost =
      opts.post.id === composerModel?.post?.id &&
      opts.action === composerModel?.action &&
      opts.draftKey === composerModel?.draftKey;

    return editingSamePost ? composer.unshrink() : composer.open(opts);
  }

  @action
  toggleBookmark(post) {
    if (!this.currentUser) {
      return this.dialog.alert(i18n("bookmarks.not_bookmarked"));
    } else if (post) {
      const bookmarkForPost = this.model.bookmarks.find(
        (bookmark) =>
          bookmark.bookmarkable_id === post.id &&
          bookmark.bookmarkable_type === "Post"
      );
      return this._modifyPostBookmark(
        bookmarkForPost ||
          Bookmark.createFor(this.currentUser, "Post", post.id),
        post
      );
    } else {
      return this._toggleTopicLevelBookmark().then((changedIds) => {
        if (!changedIds) {
          return;
        }
        changedIds.forEach((id) =>
          this.appEvents.trigger("post-stream:refresh", { id })
        );
      });
    }
  }

  @action
  jumpToIndex(index) {
    this._jumpToIndex(index);
  }

  @action
  jumpToDate(date) {
    this._jumpToDate(date);
  }

  @action
  jumpToPostPrompt() {
    this.modal.show(JumpToPost, {
      model: {
        topic: this.model,
        jumpToIndex: (index) => this.send("jumpToIndex", index),
        jumpToDate: (date) => this.send("jumpToDate", date),
      },
    });
  }

  @action
  jumpToPost(postNumber) {
    this._jumpToPostNumber(postNumber);
  }

  @action
  jumpBottom() {
    const highestPostNumber = this.model.highest_post_number;

    if (document.getElementById(`post_${highestPostNumber}`)) {
      // Do nothing when the last post is already rendered.
      // This ensures the browser handles keyboard shortcuts like End.
      return;
    }

    DiscourseURL.routeTo(this.get("model.lastPostUrl"), {
      skipIfOnScreen: false,
      jumpEnd: false,
      keepFilter: true,
    });
  }

  @action
  jumpEnd() {
    this.appEvents.trigger(
      "topic:jump-to-post",
      this.get("model.highest_post_number")
    );
    DiscourseURL.routeTo(this.get("model.lastPostUrl"), {
      jumpEnd: true,
      keepFilter: true,
    });
  }

  @action
  jumpUnread() {
    this._jumpToPostId(this.get("model.last_read_post_id"));
  }

  @action
  jumpToPostId(postId) {
    this._jumpToPostId(postId);
  }

  @action
  togglePostSelection(post) {
    const selected = this.selectedPostIds;
    selected.includes(post.id)
      ? selected.removeObject(post.id)
      : selected.addObject(post.id);
  }

  @action
  selectReplies(post) {
    ajax(`/posts/${post.id}/reply-ids.json`).then((replies) => {
      const replyIds = replies.map((r) => r.id);
      const postIds = [...this.selectedPostIds, post.id, ...replyIds];
      this.set("selectedPostIds", [...new Set(postIds)]);
      this._forceRefreshPostStream();
    });
  }

  @action
  selectBelow(post) {
    if (this.get("model.postStream.isMegaTopic")) {
      this._loadPostIds(post);
    } else {
      const stream = [...this.get("model.postStream.stream")];
      const below = stream.slice(stream.indexOf(post.id));
      this._updateSelectedPostIds(below);
    }
  }

  @action
  deleteSelected() {
    const user = this.currentUser;
    this.dialog.yesNoConfirm({
      message: i18n("post.delete.confirm", {
        count: this.selectedPostsCount,
      }),
      didConfirm: () => {
        // If all posts are selected, it's the same thing as deleting the topic
        if (this.selectedAllPosts) {
          return this.deleteTopic();
        }

        Post.deleteMany(this.selectedPostIds);
        this.get("model.postStream.posts").forEach(
          (p) => this.postSelected(p) && p.setDeletedState(user)
        );
        this.send("toggleMultiSelect");
      },
    });
  }

  @action
  mergePosts() {
    this.dialog.yesNoConfirm({
      message: i18n("post.merge.confirm", {
        count: this.selectedPostsCount,
      }),
      didConfirm: () => {
        Post.mergePosts(this.selectedPostIds);
        this.send("toggleMultiSelect");
      },
    });
  }

  @action
  changePostOwner(post) {
    this.set("selectedPostIds", [post.id]);
    this.send("changeOwner");
  }

  @action
  lockPost(post) {
    return post.updatePostField("locked", true);
  }

  @action
  unlockPost(post) {
    return post.updatePostField("locked", false);
  }

  @action
  grantBadge(post) {
    this.set("selectedPostIds", [post.id]);
    this.send("showGrantBadgeModal");
  }

  @action
  async changeNotice(post) {
    await this.modal.show(ChangePostNoticeModal, { model: { post } });
  }

  @action
  filterParticipant(user) {
    this.get("model.postStream")
      .filterParticipant(user.username)
      .then(() => this.updateQueryParams);
  }

  @action
  cancelEditingTopic() {
    this.set("editingTopic", false);
    this.rollbackBuffer();
  }

  @action
  finishedEditingTopic() {
    if (!this.editingTopic) {
      return;
    }

    // save the modifications
    const props = this.get("buffered.buffer");

    Topic.update(this.model, props, { fastEdit: true })
      .then(() => {
        // We roll back on success here because `update` saves the properties to the topic
        this.rollbackBuffer();
        this.set("editingTopic", false);
      })
      .catch(popupAjaxError);
  }

  @action
  expandHidden(post) {
    return post.expandHidden();
  }

  @action
  toggleVisibility() {
    this.model.toggleStatus("visible");
  }

  @action
  toggleClosed() {
    const topic = this.model;

    this.model.toggleStatus("closed").then((result) => {
      topic.set("topic_status_update", result.topic_status_update);
    });
  }

  @action
  makeBanner() {
    this.model.makeBanner();
  }

  @action
  removeBanner() {
    this.model.removeBanner();
  }

  @action
  togglePinned() {
    const value = this.get("model.pinned_at") ? false : true,
      topic = this.model,
      until = this.get("model.pinnedInCategoryUntil");

    // optimistic update
    topic.setProperties({
      pinned_at: value ? moment() : null,
      pinned_globally: false,
      pinned_until: value ? until : null,
    });

    return topic.saveStatus("pinned", value, until);
  }

  @action
  pinGlobally() {
    const topic = this.model,
      until = this.get("model.pinnedGloballyUntil");

    // optimistic update
    topic.setProperties({
      pinned_at: moment(),
      pinned_globally: true,
      pinned_until: until,
    });

    return topic.saveStatus("pinned_globally", true, until);
  }

  @action
  toggleArchived() {
    this.model.toggleStatus("archived");
  }

  @action
  clearPin() {
    this.model.clearPin();
  }

  @action
  togglePinnedForUser() {
    if (this.get("model.pinned_at")) {
      const topic = this.model;
      if (topic.get("pinned")) {
        topic.clearPin();
      } else {
        topic.rePin();
      }
    }
  }

  @action
  replyAsNewTopic(post) {
    const composerController = this.composer;
    const { quoteState } = this;
    const quotedText = buildQuote(post, quoteState.buffer, quoteState.opts);

    quoteState.clear();

    let options;
    if (this.get("model.isPrivateMessage")) {
      let users = this.get("model.details.allowed_users");
      let groups = this.get("model.details.allowed_groups");

      let recipients = [];
      users.forEach((user) => recipients.push(user.username));
      groups.forEach((group) => recipients.push(group.name));
      recipients = recipients.join();

      options = {
        action: Composer.PRIVATE_MESSAGE,
        archetypeId: "private_message",
        draftKey: post.topic.draft_key,
        recipients,
      };
    } else {
      options = {
        action: Composer.CREATE_TOPIC,
        draftKey: post.topic.draft_key,
        topicCategoryId: this.get("model.category.id"),
        prioritizedCategoryId: this.get("model.category.id"),
      };
    }

    composerController.open(options).then(() => {
      const title = escapeExpression(this.model.title);
      const postUrl = `${location.protocol}//${location.host}${post.url}`;
      const postLink = `[${title}](${postUrl})`;
      const text = `${i18n("post.continue_discussion", {
        postLink,
      })}\n\n${quotedText}`;

      composerController.model.prependText(text, { new_line: true });
    });
  }

  @action
  retryLoading() {
    this.set("retrying", true);
    const rollback = () => this.set("retrying", false);
    this.get("model.postStream").refresh().then(rollback, rollback);
  }

  @action
  toggleWiki(post) {
    return post.updatePostField("wiki", !post.get("wiki"));
  }

  @action
  togglePostType(post) {
    const regular = this.site.get("post_types.regular");
    const moderator = this.site.get("post_types.moderator_action");
    return post.updatePostField(
      "post_type",
      post.get("post_type") === moderator ? regular : moderator
    );
  }

  @action
  rebakePost(post) {
    return post.rebake();
  }

  @action
  unhidePost(post) {
    return post.unhide();
  }

  @action
  convertToPublicTopic() {
    this.modal.show(ConvertToPublicTopicModal, {
      model: { topic: this.model },
    });
  }

  @action
  convertToPrivateMessage() {
    this.model
      .convertTopic("private")
      .then(() => window.location.reload())
      .catch(popupAjaxError);
  }

  @action
  resetBumpDate() {
    this.model.resetBumpDate();
  }

  @action
  removeTopicTimer(statusType, topicTimer) {
    TopicTimer.update(this.get("model.id"), null, null, statusType, null)
      .then(() => this.set(`model.${topicTimer}`, EmberObject.create({})))
      .catch((error) => popupAjaxError(error));
  }

  _jumpToIndex(index) {
    const postStream = this.get("model.postStream");

    if (postStream.get("isMegaTopic")) {
      this._jumpToPostNumber(index);
    } else {
      const stream = postStream.get("stream");
      const streamIndex = Math.max(1, Math.min(stream.length, index));
      this._jumpToPostId(stream[streamIndex - 1]);
    }
  }

  _jumpToDate(date) {
    const postStream = this.get("model.postStream");

    postStream
      .loadNearestPostToDate(date)
      .then((post) => {
        DiscourseURL.routeTo(
          this.model.urlForPostNumber(post.get("post_number"))
        );
      })
      .catch(() => {
        this._jumpToIndex(postStream.get("topic.highest_post_number"));
      });
  }

  _jumpToPostNumber(postNumber) {
    const postStream = this.get("model.postStream");
    const post = postStream.get("posts").findBy("post_number", postNumber);

    if (post) {
      DiscourseURL.routeTo(
        this.model.urlForPostNumber(post.get("post_number"))
      );
    } else {
      postStream.loadPostByPostNumber(postNumber).then((p) => {
        DiscourseURL.routeTo(this.model.urlForPostNumber(p.get("post_number")));
      });
    }
  }

  _jumpToPostId(postId) {
    if (!postId) {
      // eslint-disable-next-line no-console
      console.warn(
        "jump-post code broken - requested an index outside the stream array"
      );
      return;
    }

    this.appEvents.trigger("topic:jump-to-post", postId);

    const topic = this.model;
    const postStream = topic.get("postStream");
    const post = postStream.findLoadedPost(postId);

    if (post) {
      DiscourseURL.routeTo(topic.urlForPostNumber(post.get("post_number")), {
        keepFilter: true,
      });
    } else {
      // need to load it
      postStream.findPostsByIds([postId]).then((arr) => {
        DiscourseURL.routeTo(
          topic.urlForPostNumber(arr[0].get("post_number")),
          {
            keepFilter: true,
          }
        );
      });
    }
  }

  _modifyTopicBookmark(bookmark) {
    this.modal.show(BookmarkModal, {
      model: {
        bookmark: new BookmarkFormData(bookmark),
        afterSave: (bookmarkFormData) => {
          this._syncBookmarks(bookmarkFormData.saveData);
          this.model.set("bookmarking", false);
          this.model.set("bookmarked", true);
          this.model.incrementProperty("bookmarksWereChanged");
          this.appEvents.trigger(
            "bookmarks:changed",
            bookmarkFormData.saveData,
            bookmark.attachedTo()
          );
        },
        afterDelete: (topicBookmarked, bookmarkId) => {
          this.model.removeBookmark(bookmarkId);
        },
      },
    });
  }

  _modifyPostBookmark(bookmark, post) {
    this.modal
      .show(BookmarkModal, {
        model: {
          bookmark: new BookmarkFormData(bookmark),
          afterSave: (savedData) => {
            this._syncBookmarks(savedData);
            this.model.set("bookmarking", false);
            post.createBookmark(savedData);
            this.model.afterPostBookmarked(post, savedData);
            return [post.id];
          },
          afterDelete: (topicBookmarked, bookmarkId) => {
            this.model.removeBookmark(bookmarkId);
            post.deleteBookmark(topicBookmarked);
          },
        },
      })
      .then((closeData) => {
        if (!closeData) {
          return;
        }

        if (
          closeData.closeWithoutSaving ||
          closeData.initiatedBy === CLOSE_INITIATED_BY_ESC ||
          closeData.initiatedBy === CLOSE_INITIATED_BY_BUTTON
        ) {
          post.appEvents.trigger("post-stream:refresh", {
            id: bookmark.bookmarkable_id,
          });
        }
      });
  }

  _syncBookmarks(data) {
    if (!this.model.bookmarks) {
      this.model.set("bookmarks", []);
    }

    const bookmark = this.model.bookmarks.findBy("id", data.id);
    if (!bookmark) {
      this.model.bookmarks.pushObject(Bookmark.create(data));
    } else {
      bookmark.reminder_at = data.reminder_at;
      bookmark.name = data.name;
      bookmark.auto_delete_preference = data.auto_delete_preference;
    }
  }

  async _toggleTopicLevelBookmark() {
    if (this.model.bookmarking) {
      return Promise.resolve();
    }

    if (this.model.bookmarkCount > 1) {
      return this._maybeClearAllBookmarks();
    }

    if (this.model.bookmarkCount === 1) {
      const topicBookmark = this.model.bookmarks.findBy(
        "bookmarkable_type",
        "Topic"
      );
      if (topicBookmark) {
        return this._modifyTopicBookmark(topicBookmark);
      } else {
        const bookmark = this.model.bookmarks[0];
        const post = await this.model.postById(bookmark.bookmarkable_id);
        return this._modifyPostBookmark(bookmark, post);
      }
    }

    if (this.model.bookmarkCount === 0) {
      return this._modifyTopicBookmark(
        Bookmark.createFor(this.currentUser, "Topic", this.model.id)
      );
    }
  }

  _maybeClearAllBookmarks() {
    return new Promise((resolve) => {
      this.dialog.yesNoConfirm({
        message: i18n("bookmarks.confirm_clear"),
        didConfirm: () => {
          return this.model
            .deleteBookmarks()
            .then(() => resolve(this.model.clearBookmarks()))
            .catch(popupAjaxError)
            .finally(() => {
              this.model.set("bookmarking", false);
            });
        },
        didCancel: () => {
          this.model.set("bookmarking", false);
          resolve();
        },
      });
    });
  }

  togglePinnedState() {
    this.send("togglePinnedForUser");
  }

  print() {
    if (this.siteSettings.max_prints_per_hour_per_user > 0) {
      window.open(
        this.get("model.printUrl"),
        "",
        "menubar=no,toolbar=no,resizable=yes,scrollbars=yes,width=600,height=315"
      );
    }
  }

  @discourseComputed(
    "selectedPostIds",
    "model.postStream.posts",
    "selectedPostIds.[]",
    "model.postStream.posts.[]"
  )
  selectedPosts(selectedPostIds, loadedPosts) {
    return selectedPostIds
      .map((id) => loadedPosts.find((p) => p.id === id))
      .filter((post) => post !== undefined);
  }

  @discourseComputed("selectedPostsCount", "selectedPosts", "selectedPosts.[]")
  selectedPostsUsername(selectedPostsCount, selectedPosts) {
    if (selectedPosts.length < 1 || selectedPostsCount > selectedPosts.length) {
      return undefined;
    }
    const username = selectedPosts[0].username;
    return selectedPosts.every((p) => p.username === username)
      ? username
      : undefined;
  }

  @discourseComputed(
    "selectedPostsCount",
    "model.postStream.isMegaTopic",
    "model.postStream.stream.length",
    "model.posts_count"
  )
  selectedAllPosts(
    selectedPostsCount,
    isMegaTopic,
    postsCount,
    topicPostsCount
  ) {
    if (isMegaTopic) {
      return selectedPostsCount >= topicPostsCount;
    } else {
      return selectedPostsCount >= postsCount;
    }
  }

  @discourseComputed("selectedAllPosts", "model.postStream.isMegaTopic")
  canSelectAll(selectedAllPosts, isMegaTopic) {
    return isMegaTopic ? false : !selectedAllPosts;
  }

  @discourseComputed(
    "currentUser.staff",
    "selectedPostsCount",
    "selectedAllPosts",
    "selectedPosts",
    "selectedPosts.[]"
  )
  canDeleteSelected(
    isStaff,
    selectedPostsCount,
    selectedAllPosts,
    selectedPosts
  ) {
    return (
      selectedPostsCount > 0 &&
      ((selectedAllPosts && isStaff) ||
        selectedPosts.every((p) => p.can_delete))
    );
  }

  @discourseComputed("model.details.can_move_posts", "selectedPostsCount")
  canMergeTopic(canMovePosts, selectedPostsCount) {
    return canMovePosts && selectedPostsCount > 0;
  }

  @discourseComputed(
    "currentUser.admin",
    "currentUser.staff",
    "siteSettings.moderators_change_post_ownership",
    "selectedPostsCount",
    "selectedPostsUsername"
  )
  canChangeOwner(
    isAdmin,
    isStaff,
    modChangePostOwner,
    selectedPostsCount,
    selectedPostsUsername
  ) {
    return (
      (isAdmin || (modChangePostOwner && isStaff)) &&
      selectedPostsCount > 0 &&
      selectedPostsUsername !== undefined
    );
  }

  @discourseComputed(
    "selectedPostsCount",
    "selectedPostsUsername",
    "selectedPosts",
    "selectedPosts.[]"
  )
  canMergePosts(selectedPostsCount, selectedPostsUsername, selectedPosts) {
    return (
      selectedPostsCount > 1 &&
      selectedPostsUsername !== undefined &&
      selectedPosts.every((p) => p.can_delete)
    );
  }

  @observes("multiSelect")
  _multiSelectChanged() {
    this.set("selectedPostIds", []);
  }

  postSelected(post) {
    return this.selectedAllPost || this.selectedPostIds.includes(post.id);
  }

  @discourseComputed
  loadingHTML() {
    return spinnerHTML;
  }

  @action
  recoverTopic() {
    this.model.recover();
  }

  @action
  buildQuoteMarkdown() {
    const { postId, buffer, opts } = this.quoteState;
    const loadedPost = this.get("model.postStream").findLoadedPost(postId);
    const promise = loadedPost
      ? Promise.resolve(loadedPost)
      : this.get("model.postStream").loadPost(postId);

    return promise.then((post) => {
      return buildQuote(post, buffer, opts);
    });
  }

  @action
  deleteTopic(opts = {}) {
    if (opts.force_destroy) {
      return this.model.destroy(this.currentUser, opts);
    }

    if (
      this.model.views > this.siteSettings.min_topic_views_for_delete_confirm
    ) {
      this.deleteTopicModal();
    } else {
      this.model.destroy(this.currentUser, opts);
    }
  }

  deleteTopicModal() {
    this.modal.show(DeleteTopicConfirmModal, { model: { topic: this.model } });
  }

  retryOnRateLimit(times, promise, topicId) {
    const currentTopicId = this.get("model.id");
    topicId = topicId || currentTopicId;
    if (topicId !== currentTopicId) {
      // we navigated to another topic, so skip
      return;
    }

    if (this._retryRateLimited || times <= 0) {
      return;
    }

    if (this._retryInProgress) {
      discourseLater(() => {
        this.retryOnRateLimit(times, promise, topicId);
      }, 100);
      return;
    }

    this._retryInProgress = true;

    promise()
      .catch((e) => {
        const xhr = e.jqXHR;
        if (
          xhr &&
          xhr.status === 429 &&
          xhr.responseJSON &&
          xhr.responseJSON.extras &&
          xhr.responseJSON.extras.wait_seconds
        ) {
          let waitSeconds = xhr.responseJSON.extras.wait_seconds;
          if (waitSeconds < 5) {
            waitSeconds = 5;
          }

          this._retryRateLimited = true;

          discourseLater(() => {
            this._retryRateLimited = false;
            this.retryOnRateLimit(times - 1, promise, topicId);
          }, waitSeconds * 1000);
        }
      })
      .finally(() => {
        this._retryInProgress = false;
      });
  }

  subscribe() {
    this.unsubscribe();

    this.messageBus.subscribe(
      `/topic/${this.get("model.id")}`,
      this.onMessage,
      this.get("model.message_bus_last_id")
    );
  }

  unsubscribe() {
    // never unsubscribe when navigating from topic to topic
    if (!this.get("model.id")) {
      return;
    }

    this.messageBus.unsubscribe("/topic/*", this.onMessage);
  }

  @bind
  onMessage(data) {
    const topic = this.model;
    const refresh = (args) =>
      this.appEvents.trigger("post-stream:refresh", args);

    if (isPresent(data.notification_level_change)) {
      topic.set("details.notification_level", data.notification_level_change);
      topic.set(
        "details.notifications_reason_id",
        data.notifications_reason_id
      );
      return;
    }

    const postStream = this.get("model.postStream");

    if (data.reload_topic) {
      topic.reload().then(() => {
        this.send("postChangedRoute", topic.get("post_number") || 1);
        this.appEvents.trigger("header:update-topic", topic);
        if (data.refresh_stream) {
          postStream.refresh();
        }
      });

      return;
    }

    switch (data.type) {
      case "acted":
        postStream
          .triggerChangedPost(data.id, data.updated_at, {
            preserveCooked: true,
          })
          .then(() => refresh({ id: data.id, refreshLikes: true }));
        break;
      case "read": {
        postStream
          .triggerReadPost(data.id, data.readers_count)
          .then(() => refresh({ id: data.id, refreshLikes: true }));
        break;
      }
      case "liked":
      case "unliked": {
        postStream
          .triggerLikedPost(data.id, data.likes_count, data.user_id, data.type)
          .then(() => refresh({ id: data.id, refreshLikes: true }));
        break;
      }
      case "revised":
      case "rebaked": {
        postStream
          .triggerChangedPost(data.id, data.updated_at)
          .then(() => refresh({ id: data.id }));
        break;
      }
      case "deleted": {
        postStream
          .triggerDeletedPost(data.id)
          .then(() => refresh({ id: data.id }));
        break;
      }
      case "destroyed": {
        postStream
          .triggerDestroyedPost(data.id)
          .then(() => refresh({ id: data.id }));
        break;
      }
      case "recovered": {
        postStream
          .triggerRecoveredPost(data.id)
          .then(() => refresh({ id: data.id }));
        break;
      }
      case "created": {
        this._newPostsInStream.push(data.id);

        this.retryOnRateLimit(RETRIES_ON_RATE_LIMIT, () => {
          const postIds = this._newPostsInStream;
          this._newPostsInStream = [];

          return postStream
            .triggerNewPostsInStream(postIds, { background: true })
            .then(() => refresh())
            .catch((e) => {
              this._newPostsInStream = postIds.concat(this._newPostsInStream);
              throw e;
            });
        });

        if (this.get("currentUser.id") !== data.user_id) {
          this.documentTitle.incrementBackgroundContextCount();
        }
        break;
      }
      case "move_to_inbox": {
        topic.set("message_archived", false);
        break;
      }
      case "archived": {
        topic.set("message_archived", true);
        break;
      }
      case "stats": {
        let updateStream = false;
        ["last_posted_at", "like_count", "posts_count"].forEach((property) => {
          const value = data[property];
          if (typeof value !== "undefined") {
            topic.set(property, value);
            updateStream = true;
          }
        });

        if (data["last_poster"]) {
          topic.details.set("last_poster", data["last_poster"]);
          updateStream = true;
        }

        if (updateStream) {
          postStream
            .triggerChangedTopicStats()
            .then((firstPostId) => refresh({ id: firstPostId }));
        }
        break;
      }
      default: {
        let callback = customPostMessageCallbacks[data.type];
        if (callback) {
          callback(this, data);
        } else {
          // eslint-disable-next-line no-console
          console.warn("unknown topic bus message type", data);
        }
      }
    }
  }

  reply() {
    this.replyToPost();
  }

  readPosts(topicId, postNumbers) {
    const topic = this.model;
    const postStream = topic.get("postStream");

    if (topic.get("id") === topicId) {
      postStream.get("posts").forEach((post) => {
        if (!post.read && postNumbers.includes(post.post_number)) {
          post.set("read", true);
          this.appEvents.trigger("post-stream:refresh", { id: post.get("id") });
        }
      });

      if (
        this.siteSettings.automatically_unpin_topics &&
        this.currentUser &&
        this.currentUser.user_option.automatically_unpin_topics
      ) {
        // automatically unpin topics when the user reaches the bottom
        const max = Math.max(...postNumbers);
        if (topic.get("pinned") && max >= topic.get("highest_post_number")) {
          next(() => topic.clearPin());
        }
      }
    }
  }
}
