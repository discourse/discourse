import { tracked } from "@glimmer/tracking";
import Controller from "@ember/controller";
import { action } from "@ember/object";
import { getOwner } from "@ember/owner";
import { service } from "@ember/service";
import NestedActivityLog from "discourse/components/modal/nested-activity-log";
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
  @service header;
  @service messageBus;
  @service modal;
  @service nestedRootElements;
  @service nestedViewCache;
  @service router;
  @service site;

  @tracked topic;
  @tracked opPost;
  @tracked rootNodes = [];
  @tracked page = 0;
  // firstLoadedPage and page (= lastLoadedPage) bracket the current loaded
  // window of root pages. Sequential infinite scroll grows the window
  // forwards via loadMoreRoots and backwards via loadPreviousRoots; a
  // timeline jump collapses the window to a single page and the user can
  // then expand it in either direction.
  @tracked firstLoadedPage = 0;
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
  @tracked editingTopic = false;
  @tracked pinnedPostIds = [];
  @tracked rootSummary = null;
  // Persisted in the URL across in-topic navigation by design — once a
  // user lands via a consolidated reply notification, browsing within
  // the topic keeps the collapsed view, and the URL is shareable in that
  // state. If we ever want to scope it to entry-only, clear after the
  // initial render in the route.
  @tracked collapseReplies = false;
  queryParams = ["sort", "context", { collapseReplies: "collapse_replies" }];

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
  #postEventsSubscribed = false;
  #messageBusChannel = null;
  #pendingPostIds = new Set();

  // The topic controller/route are hydrated in setupController so we can
  // delegate shared actions and read shared state instead of duplicating
  // core logic.
  get #topicController() {
    return getOwner(this).lookup("controller:topic");
  }

  get #topicRoute() {
    return getOwner(this).lookup("route:topic");
  }

  get buffered() {
    return this.#topicController.buffered;
  }

  get showCategoryChooser() {
    return this.#topicController.showCategoryChooser;
  }

  get canEditTags() {
    return this.#topicController.canEditTags;
  }

  get minimumRequiredTags() {
    return this.#topicController.minimumRequiredTags;
  }

  get hasMoreRootsBefore() {
    return this.firstLoadedPage > 0;
  }

  // Non-contiguous jump: collapses the loaded window to a single target
  // page. After the jump, the user can grow the window forward
  // (loadMoreRoots) or backward (loadPreviousRoots) — no sequential
  // pagination is required to navigate elsewhere.
  @action
  async jumpToRootPage(targetPage, targetPostNumber = null) {
    if (this.loadingMore) {
      return;
    }
    if (
      targetPage >= this.firstLoadedPage &&
      targetPage <= this.page &&
      this.rootNodes.length > 0
    ) {
      // Already inside the loaded window — just scroll.
      const inWindow =
        targetPostNumber && this.#scrollToLoadedRoot(targetPostNumber);
      if (!inWindow) {
        this.#scrollToLoadedRootPage(targetPage);
      }
      return;
    }

    this.loadingMore = true;
    try {
      const data = await ajax(
        `/n/${this.topic.slug}/${this.topic.id}.json?page=${targetPage}&sort=${this.sort}`
      );

      const newNodes = (data.roots || []).map((root) =>
        this.#processNode(root)
      );

      // Pick the scroll target post number BEFORE swapping rootNodes so
      // we can await its registration in the registry rather than
      // guessing at render timing with afterRender+rAF.
      const scrollTargetPostNumber =
        targetPostNumber ?? newNodes[0]?.post?.post_number ?? null;

      this.rootNodes = newNodes;
      this.firstLoadedPage = data.page;
      this.page = data.page;
      this.hasMoreRoots = data.has_more_roots || false;
      // The backend piggybacks suggested/related on whichever response
      // has has_more_roots=false. If a jump lands on the final page,
      // skipping this leaves MoreTopics rendering with no suggestions.
      this.#assignSuggestedAndRelated(data);

      // Always land the user inside the new loaded window. Without an
      // explicit target post, the previous scrollY is stale (often past
      // the new shorter content's end) and the bottom sentinel triggers
      // a cascade of loadMore calls.
      if (scrollTargetPostNumber != null) {
        const element = await this.nestedRootElements.waitForElement(
          scrollTargetPostNumber
        );
        this.#scrollToRootWrapper(element);
      }
    } catch (e) {
      popupAjaxError(e);
    } finally {
      this.loadingMore = false;
    }
  }

  #scrollToLoadedRootPage(targetPage) {
    const ordered = this.nestedRootElements.elementsInOrder();
    if (ordered.length === 0) {
      return;
    }

    const pageSize = this.rootSummary?.page_size;
    if (!pageSize) {
      this.#scrollToRootWrapper(ordered[0].el);
      return;
    }

    let targetIndex = (targetPage - this.firstLoadedPage) * pageSize;
    if (this.firstLoadedPage === 0 && targetPage > 0) {
      const pinnedIds = new Set(this.pinnedPostIds);
      targetIndex += this.rootNodes.filter((node) =>
        pinnedIds.has(node.post.id)
      ).length;
    }

    const clamped = Math.max(0, Math.min(targetIndex, ordered.length - 1));
    this.#scrollToRootWrapper(ordered[clamped].el);
  }

  // Backwards infinite scroll. Prepends the previous page to rootNodes and
  // compensates window scroll so the user's current viewport anchor (the
  // first wrapper that was visible before the prepend) stays put. Without
  // the compensation, prepending content above the viewport would push the
  // visible content downward by the height of the new content.
  @action
  async loadPreviousRoots() {
    if (this.loadingMore || !this.hasMoreRootsBefore) {
      return;
    }

    // Capture an anchor + its viewport position BEFORE mutation. The
    // first registered root is the boundary between old/new content
    // after the prepend; preserving its `top` keeps the user's
    // current reading position visually stationary.
    const anchorEl = this.nestedRootElements.firstElement();
    const anchorPostNumber = anchorEl
      ? (this.nestedRootElements
          .elementsInOrder()
          .find((entry) => entry.el === anchorEl)?.postNumber ?? null)
      : null;
    const anchorTopBefore = anchorEl?.getBoundingClientRect().top ?? null;

    this.loadingMore = true;
    try {
      const targetPage = this.firstLoadedPage - 1;
      const data = await ajax(
        `/n/${this.topic.slug}/${this.topic.id}.json?page=${targetPage}&sort=${this.sort}`
      );

      const newNodes = (data.roots || []).map((root) =>
        this.#processNode(root)
      );

      this.rootNodes = [...newNodes, ...this.rootNodes];
      this.firstLoadedPage = data.page;
      // Same final-page piggyback concern as in jumpToRootPage — if
      // the user previously scrolled to the bottom (loading suggested)
      // and a previous-page prepend ended up being the final-page
      // response, suggested would never attach without this.
      this.#assignSuggestedAndRelated(data);

      // Wait for the prepended roots to register so the layout has
      // settled before we re-measure the anchor.
      const newFirstPostNumber = newNodes[0]?.post?.post_number;
      if (newFirstPostNumber != null) {
        await this.nestedRootElements.waitForElement(newFirstPostNumber);
      }

      if (anchorPostNumber != null && anchorTopBefore != null) {
        const liveAnchor = this.nestedRootElements.getElement(anchorPostNumber);
        if (liveAnchor) {
          const anchorTopAfter = liveAnchor.getBoundingClientRect().top;
          const delta = anchorTopAfter - anchorTopBefore;
          if (delta !== 0) {
            window.scrollBy({ top: delta, behavior: "auto" });
          }
        }
      }
    } catch (e) {
      popupAjaxError(e);
    } finally {
      this.loadingMore = false;
    }
  }

  #scrollToLoadedRoot(postNumber) {
    if (!postNumber) {
      return false;
    }
    const element = this.nestedRootElements.getElement(postNumber);
    if (!element) {
      return false;
    }
    this.#scrollToRootWrapper(element);
    return true;
  }

  #scrollToRootWrapper(wrapper) {
    if (!wrapper) {
      return;
    }
    const headerOffset = this.header.headerOffset ?? 0;
    const top =
      wrapper.getBoundingClientRect().top + window.scrollY - headerOffset - 8;
    window.scrollTo({ top, behavior: "auto" });
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
        `/n/${this.topic.slug}/${this.topic.id}.json?page=${nextPage}&sort=${this.sort}`
      );

      const newNodes = (data.roots || []).map((root) =>
        this.#processNode(root)
      );

      this.rootNodes = [...this.rootNodes, ...newNodes];
      this.page = data.page;
      this.hasMoreRoots = data.has_more_roots || false;
      this.#assignSuggestedAndRelated(data);
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
        { queryParams: { sort: this.sort, context: null } }
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
    this.#topicController.editPost(post);
    this.composer.set("skipJumpOnSave", true);
  }

  @action
  deletePost(post) {
    if (!post.can_delete) {
      return;
    }

    this.dialog.yesNoConfirm({
      message: i18n("post.confirm_delete"),
      didConfirm: () => {
        post
          .destroy(this.currentUser)
          .then(() => this.#markPostDeletedLocally(post.id))
          .catch(popupAjaxError);
      },
    });
  }

  @action
  recoverPost(post) {
    this.#topicController.recoverPost(post);
  }

  @action
  async togglePinPost(post) {
    if (!this.currentUser?.staff) {
      return;
    }

    try {
      const result = await ajax(
        `/n/${this.topic.slug}/${this.topic.id}/pin.json`,
        {
          type: "PUT",
          data: { post_id: post.id },
        }
      );

      this.pinnedPostIds = result.pinned_post_ids || [];

      if (this.pinnedPostIds.includes(post.id)) {
        // Move newly pinned post to front of rootNodes
        const idx = this.rootNodes.findIndex((n) => n.post.id === post.id);
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
    const tc = this.#topicController;
    const { postId, buffer, opts } = this.quoteState;
    this.#ensurePostInStream(postId);
    tc.quoteState.selected(postId, buffer, opts);
    return tc.selectText();
  }

  @action
  buildQuoteMarkdown() {
    const tc = this.#topicController;
    const { postId, buffer, opts } = this.quoteState;
    this.#ensurePostInStream(postId);
    tc.quoteState.selected(postId, buffer, opts);
    return tc.buildQuoteMarkdown();
  }

  #ensurePostInStream(postId) {
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
    this.#topicRoute.showHistory(post);
  }

  @action
  showFlags(post) {
    this.#topicRoute.showFlags(post);
  }

  @action
  showActivityLog() {
    this.modal.show(NestedActivityLog, {
      model: { topic: this.topic },
    });
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
    this.#topicController.set("editingTopic", true);
  }

  @action
  cancelEditingTopic() {
    this.#topicController.cancelEditingTopic();
    this.editingTopic = false;
  }

  @action
  finishedEditingTopic() {
    this.#topicController.finishedEditingTopic();
    this.editingTopic = false;
  }

  @action
  topicCategoryChanged(categoryId) {
    this.#topicController.topicCategoryChanged(categoryId);
  }

  @action
  topicTagsChanged(value) {
    this.#topicController.topicTagsChanged(value);
  }

  subscribe() {
    this.unsubscribe();

    this.appEvents.on(
      "nested-replies:post-registered",
      this,
      this.#onPostRegistered
    );
    this.appEvents.on(
      "nested-replies:post-unregistered",
      this,
      this.#onPostUnregistered
    );
    this.#postEventsSubscribed = true;

    // Register the OP post directly since it's not rendered by NestedPost
    if (this.opPost) {
      this.postRegistry.set(this.opPost.post_number, this.opPost);
    }

    if (this.topic?.id && this.messageBusLastId != null) {
      this.#messageBusChannel = `/topic/${this.topic.id}`;
      this.messageBus.subscribe(
        this.#messageBusChannel,
        this._onMessage,
        this.messageBusLastId
      );
    }
  }

  unsubscribe() {
    if (this.#postEventsSubscribed) {
      this.appEvents.off(
        "nested-replies:post-registered",
        this,
        this.#onPostRegistered
      );
      this.appEvents.off(
        "nested-replies:post-unregistered",
        this,
        this.#onPostUnregistered
      );
      this.#postEventsSubscribed = false;
    }
    if (this.#messageBusChannel) {
      this.messageBus.unsubscribe(this.#messageBusChannel, this._onMessage);
      this.#messageBusChannel = null;
    }
    this.postRegistry.clear();
  }

  #onPostRegistered(post) {
    if (post?.post_number != null) {
      this.postRegistry.set(post.post_number, post);
    }
  }

  #onPostUnregistered(post) {
    if (post?.post_number != null) {
      this.postRegistry.delete(post.post_number);
    }
  }

  @bind
  _onMessage(data, globalId, messageId) {
    if (messageId != null) {
      this.messageBusLastId = messageId;
    }

    switch (data.type) {
      case "created":
        this.#handleCreated(data);
        break;
      case "revised":
      case "rebaked":
      case "deleted":
      case "recovered":
      case "acted":
        this.#handlePostChanged(data);
        break;
    }
  }

  async #handleCreated(data) {
    // Skip if this post is already known (e.g. cache restore replaying
    // messages that were already processed before navigating away)
    if (this.#isPostKnown(data.id) || this.#pendingPostIds.has(data.id)) {
      return;
    }

    this.#pendingPostIds.add(data.id);
    const topicId = this.topic?.id;
    try {
      const postData = await ajax(`/posts/${data.id}.json`);
      if (this.topic?.id !== topicId) {
        return;
      }

      if (!this.#isVisibleInTree(postData)) {
        return;
      }

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
    } finally {
      this.#pendingPostIds.delete(data.id);
    }
  }

  // Mirrors the server-side filter in NestedReplies::TreeLoader#apply_visibility:
  // small_action posts (close/open/etc.) belong in the activity log, not the tree;
  // whispers with an action_code (e.g. assigns) are likewise activity-log-only.
  #isVisibleInTree(postData) {
    const postTypes = this.site.post_types;
    if (postData.post_type === postTypes.small_action) {
      return false;
    }
    if (postData.post_type === postTypes.whisper && postData.action_code) {
      return false;
    }
    return true;
  }

  #isPostKnown(postId) {
    if (this.rootNodes.some((n) => n.post.id === postId)) {
      return true;
    }
    if (this.newRootPostIds.includes(postId)) {
      return true;
    }
    for (const post of this.postRegistry.values()) {
      if (post.id === postId) {
        return true;
      }
    }
    return false;
  }

  async #handlePostChanged(data) {
    if (data.type === "deleted") {
      this.#markPostDeletedLocally(data.id);
      return;
    }

    const topicId = this.topic?.id;
    try {
      const postData = await ajax(`/posts/${data.id}.json`);
      if (this.topic?.id !== topicId) {
        return;
      }

      const existing = [...this.postRegistry.values()].find(
        (p) => p.id === data.id
      );
      if (existing) {
        existing.setProperties(postData);
        if (!postData.deleted_at) {
          existing.set("deleted_post_placeholder", false);
        }
      }
    } catch {
      // Post may not be visible
    }
  }

  #markPostDeletedLocally(postId) {
    for (const post of this.postRegistry.values()) {
      if (post.id === postId) {
        post.set("deleted_at", new Date());
        post.set("deleted_post_placeholder", true);
        if (!this.currentUser?.staff) {
          post.set("cooked", "");
        }
        break;
      }
    }
  }

  @action
  async loadNewRoots() {
    const ids = [...this.newRootPostIds];
    this.newRootPostIds = [];

    const topicId = this.topic?.id;
    const results = await Promise.allSettled(
      ids.map((id) => ajax(`/posts/${id}.json`))
    );

    if (this.topic?.id !== topicId) {
      return;
    }

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

  #processNode(nodeData) {
    return processNode(this.store, this.topic, nodeData);
  }

  #assignSuggestedAndRelated(data) {
    if (!this.topic) {
      return;
    }
    if (data.suggested_topics !== undefined) {
      this.topic.suggested_topics = data.suggested_topics;
    }
    if (data.related_topics !== undefined) {
      this.topic.related_topics = data.related_topics;
    }
    if (data.related_messages !== undefined) {
      this.topic.related_messages = data.related_messages;
    }
    if (data.suggested_group_name !== undefined) {
      this.topic.suggested_group_name = data.suggested_group_name;
    }
  }
}
