import { tracked } from "@glimmer/tracking";
import Controller from "@ember/controller";
import { action } from "@ember/object";
import { getOwner } from "@ember/owner";
import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { bind } from "discourse/lib/decorators";
import QuoteState from "discourse/lib/quote-state";
import Composer from "discourse/models/composer";
import { i18n } from "discourse-i18n";
import processNode from "../lib/process-node";

export default class NestedController extends Controller {
  @service appEvents;
  @service composer;
  @service store;
  @service dialog;
  @service currentUser;
  @service messageBus;
  @service nestedViewCache;
  @service router;

  @tracked topic;
  @tracked opPost;
  @tracked rootNodes = [];
  @tracked page = 0;
  @tracked hasMoreRoots = false;
  @tracked loadingMore = false;
  @tracked sort;
  @tracked messageBusLastId;
  @tracked postNumber;
  @tracked contextMode = false;
  @tracked contextChain = null;
  @tracked targetPostNumber = null;
  @tracked contextNoAncestors = false;
  @tracked ancestorsTruncated = false;
  @tracked topAncestorPostNumber = null;
  @tracked newRootPostIds = [];
  @tracked postScreenTracker = null;
  @tracked editingTopic = false;
  @tracked pinnedPostNumber = null;
  queryParams = ["sort", "context"];

  // Externalized expansion state: postNumber → { expanded, collapsed }
  // Components read on construction, write on toggle.
  // Persisted across back/forward navigations via NestedViewCache.
  expansionState = new Map();

  // Cache of dynamically loaded children: postNumber → { childNodes, page, hasMore, fetchedFromServer }
  // Populated by NestedPostChildren on every mutation, read on restoration.
  fetchedChildrenCache = new Map();

  // Scroll anchor for cache restoration: { postNumber, offsetFromTop }
  scrollAnchor = null;

  quoteState = new QuoteState();

  // Flat registry of all rendered posts by post_number.
  // Populated by NestedPost components via appEvents so that readPosts
  // can find posts at any depth, not just those in the preloaded tree.
  postRegistry = new Map();
  _postEventsSubscribed = false;

  // The topic controller/route are hydrated in setupController so we can
  // delegate shared actions and read shared state instead of duplicating
  // core logic.
  get _topicController() {
    return getOwner(this).lookup("controller:topic");
  }

  get _topicRoute() {
    return getOwner(this).lookup("route:topic");
  }

  get buffered() {
    return this._topicController.buffered;
  }

  get showCategoryChooser() {
    return this._topicController.showCategoryChooser;
  }

  get canEditTags() {
    return this._topicController.canEditTags;
  }

  get minimumRequiredTags() {
    return this._topicController.minimumRequiredTags;
  }

  @action
  async loadMoreRoots() {
    if (this.loadingMore || !this.hasMoreRoots) {
      return;
    }

    this.loadingMore = true;
    try {
      const nextPage = this.page + 1;
      const data = await ajax(
        `/n/${this.topic.slug}/${this.topic.id}/roots.json?page=${nextPage}&sort=${this.sort}`
      );

      const newNodes = (data.roots || []).map((root) =>
        this._processNode(root)
      );

      this.rootNodes = [...this.rootNodes, ...newNodes];
      this.page = data.page;
      this.hasMoreRoots = data.has_more_roots || false;
    } catch (e) {
      popupAjaxError(e);
    } finally {
      this.loadingMore = false;
    }
  }

  @action
  changeSort(newSort) {
    this.router.transitionTo({ queryParams: { sort: newSort } });
  }

  @action
  viewFullThread() {
    this.nestedViewCache.useNextTransition();
    this.router.transitionTo("nested", this.topic.slug, this.topic.id, {
      queryParams: { sort: this.sort, context: null },
    });
  }

  @action
  viewParentContext() {
    if (this.ancestorsTruncated && this.topAncestorPostNumber) {
      this.router.transitionTo(
        "nestedPost",
        this.topic.slug,
        this.topic.id,
        this.topAncestorPostNumber,
        { queryParams: { sort: this.sort } }
      );
    } else {
      this.router.transitionTo(
        "nestedPost",
        this.topic.slug,
        this.topic.id,
        this.targetPostNumber,
        { queryParams: { sort: this.sort } }
      );
    }
  }

  @action
  replyToPost(post) {
    const topic = this.topic;
    if (!topic.details?.can_create_post) {
      return;
    }

    let replyTarget = post;

    const opts = {
      action: Composer.REPLY,
      draftKey: topic.draft_key,
      draftSequence: topic.draft_sequence || 0,
      skipJumpOnSave: true,
    };

    if (replyTarget && replyTarget.post_number !== 1) {
      opts.post = replyTarget;
    } else {
      opts.topic = topic;
    }

    this.composer.open(opts);
  }

  @action
  editPost(post) {
    this._topicController.editPost(post);
  }

  @action
  deletePost(post) {
    if (!post.can_delete) {
      return;
    }

    this.dialog.yesNoConfirm({
      message: i18n("post.confirm_delete"),
      didConfirm: () => {
        post.destroy(this.currentUser).catch(popupAjaxError);
      },
    });
  }

  @action
  recoverPost(post) {
    this._topicController.recoverPost(post);
  }

  @action
  async togglePinPost(post) {
    if (!this.currentUser?.staff) {
      return;
    }

    const isPinned = this.pinnedPostNumber === post.post_number;
    const newValue = isPinned ? null : post.post_number;

    try {
      await ajax(`/n/${this.topic.slug}/${this.topic.id}/pin.json`, {
        type: "PUT",
        data: { post_number: newValue },
      });

      this.pinnedPostNumber = newValue;

      if (newValue) {
        // Move pinned post to front of rootNodes
        const idx = this.rootNodes.findIndex(
          (n) => n.post.post_number === newValue
        );
        if (idx > 0) {
          const pinned = this.rootNodes[idx];
          const rest = this.rootNodes.filter((_, i) => i !== idx);
          this.rootNodes = [pinned, ...rest];
        }
      }
    } catch (e) {
      popupAjaxError(e);
    }
  }

  @action
  selectText() {
    const tc = this._topicController;
    const { postId, buffer, opts } = this.quoteState;
    this._ensurePostInStream(postId);
    tc.quoteState.selected(postId, buffer, opts);
    return tc.selectText();
  }

  @action
  buildQuoteMarkdown() {
    const tc = this._topicController;
    const { postId, buffer, opts } = this.quoteState;
    this._ensurePostInStream(postId);
    tc.quoteState.selected(postId, buffer, opts);
    return tc.buildQuoteMarkdown();
  }

  _ensurePostInStream(postId) {
    const postStream = this.topic?.postStream;
    if (!postStream) {
      return;
    }

    const id = parseInt(postId, 10);
    if (!postStream.findLoadedPost(id)) {
      for (const post of this.postRegistry.values()) {
        if (post.id === id) {
          postStream.storePost(post);
          break;
        }
      }
    }
  }

  @action
  showHistory(post) {
    this._topicRoute.showHistory(post);
  }

  @action
  showFlags(post) {
    this._topicRoute.showFlags(post);
  }

  // editingTopic is @tracked locally because the topic controller's
  // editingTopic is a classic property (not @tracked) — a plain getter
  // aliasing it won't trigger Glimmer re-renders. We sync the flag to
  // the topic controller so its finishedEditingTopic save logic works.
  @action
  startEditingTopic(event) {
    event?.preventDefault();
    if (!this.topic?.details?.can_edit) {
      return;
    }
    this.editingTopic = true;
    this._topicController.set("editingTopic", true);
  }

  @action
  cancelEditingTopic() {
    this._topicController.cancelEditingTopic();
    this.editingTopic = false;
  }

  @action
  finishedEditingTopic() {
    this._topicController.finishedEditingTopic();
    this.editingTopic = false;
  }

  @action
  topicCategoryChanged(categoryId) {
    this._topicController.topicCategoryChanged(categoryId);
  }

  @action
  topicTagsChanged(value) {
    this._topicController.topicTagsChanged(value);
  }

  subscribe() {
    this.unsubscribe();

    this.appEvents.on(
      "nested-replies:post-registered",
      this,
      this._onPostRegistered
    );
    this.appEvents.on(
      "nested-replies:post-unregistered",
      this,
      this._onPostUnregistered
    );
    this._postEventsSubscribed = true;

    // Register the OP post directly since it's not rendered by NestedPost
    if (this.opPost) {
      this.postRegistry.set(this.opPost.post_number, this.opPost);
    }

    if (this.topic?.id && this.messageBusLastId != null) {
      this._messageBusChannel = `/topic/${this.topic.id}`;
      this.messageBus.subscribe(
        this._messageBusChannel,
        this._onMessage,
        this.messageBusLastId
      );
    }
  }

  unsubscribe() {
    if (this._postEventsSubscribed) {
      this.appEvents.off(
        "nested-replies:post-registered",
        this,
        this._onPostRegistered
      );
      this.appEvents.off(
        "nested-replies:post-unregistered",
        this,
        this._onPostUnregistered
      );
      this._postEventsSubscribed = false;
    }
    if (this._messageBusChannel) {
      this.messageBus.unsubscribe(this._messageBusChannel, this._onMessage);
      this._messageBusChannel = null;
    }
    this.postRegistry.clear();
  }

  _onPostRegistered(post) {
    if (post?.post_number != null) {
      this.postRegistry.set(post.post_number, post);
    }
  }

  _onPostUnregistered(post) {
    if (post?.post_number != null) {
      this.postRegistry.delete(post.post_number);
    }
  }

  @bind
  _onMessage(data) {
    switch (data.type) {
      case "created":
        this._handleCreated(data);
        break;
      case "revised":
      case "rebaked":
      case "deleted":
      case "recovered":
      case "acted":
        this._handlePostChanged(data);
        break;
    }
  }

  async _handleCreated(data) {
    try {
      const postData = await ajax(`/posts/${data.id}.json`);
      const post = this.store.createRecord("post", postData);
      post.topic = this.topic;

      const replyTo = postData.reply_to_post_number;
      const isRoot = !replyTo || replyTo === 1;

      if (isRoot) {
        if (data.user_id === this.currentUser?.id) {
          this.rootNodes = [{ post, children: [] }, ...this.rootNodes];
        } else {
          this.newRootPostIds = [...this.newRootPostIds, data.id];
        }
      } else {
        this.appEvents.trigger("nested-replies:child-created", {
          post,
          parentPostNumber: replyTo,
          isOwnPost: data.user_id === this.currentUser?.id,
        });
      }
    } catch {
      // Post may not be visible to this user
    }
  }

  async _handlePostChanged(data) {
    if (data.type === "deleted") {
      this._markPostDeletedLocally(data.id);
      return;
    }

    try {
      const postData = await ajax(`/posts/${data.id}.json`);
      const post = this.store.createRecord("post", postData);
      post.topic = this.topic;
    } catch {
      // Post may not be visible
    }
  }

  _markPostDeletedLocally(postId) {
    for (const post of this.postRegistry.values()) {
      if (post.id === postId) {
        post.set("deleted", true);
        post.set("deleted_post_placeholder", true);
        post.set("cooked", "");
        break;
      }
    }
  }

  @action
  async loadNewRoots() {
    const ids = [...this.newRootPostIds];
    this.newRootPostIds = [];

    const results = await Promise.allSettled(
      ids.map((id) => ajax(`/posts/${id}.json`))
    );

    const newNodes = [];
    for (const result of results) {
      if (result.status === "fulfilled") {
        const postData = result.value;
        const post = this.store.createRecord("post", postData);
        post.topic = this.topic;
        newNodes.push({ post, children: [] });
      }
    }

    if (newNodes.length > 0) {
      this.rootNodes = [...newNodes, ...this.rootNodes];
    }
  }

  readPosts(topicId, postNumbers) {
    if (this.topic?.id !== topicId) {
      return;
    }

    for (const postNumber of postNumbers) {
      const post = this.postRegistry.get(postNumber);
      if (post && !post.read) {
        post.set("read", true);
      }
    }
  }

  _processNode(nodeData) {
    return processNode(this.store, this.topic, nodeData);
  }
}
