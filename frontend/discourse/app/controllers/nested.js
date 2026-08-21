import { tracked } from "@glimmer/tracking";
import Controller from "@ember/controller";
import { action } from "@ember/object";
import { getOwner } from "@ember/owner";
import { schedule } from "@ember/runloop";
import { service } from "@ember/service";
import NestedActivityLog from "discourse/components/modal/nested-activity-log";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { bind } from "discourse/lib/decorators";
import {
  NESTED_VIEW_CACHE_FORMAT_VERSION,
  snapshotExpansionState,
  snapshotFetchedChildrenCache,
  snapshotNestedModelData,
} from "discourse/lib/nested-view-cache-snapshot";
import { headerOffset } from "discourse/lib/offset-calculator";
import QuoteState from "discourse/lib/quote-state";
import Composer from "discourse/models/composer";
import Post from "discourse/models/post";
import { i18n } from "discourse-i18n";
import processNode, {
  registerPostInTopicPostStream,
} from "../lib/process-node";

const ROOT_WINDOW_PAGE_LIMIT = 3;
const ROOT_PAGE_CACHE_LIMIT = 6;
const ROOT_PAGE_CACHE_TTL_MS = 2 * 60 * 1000;

export default class NestedController extends Controller {
  @service appEvents;
  @service composer;
  @service store;
  @service dialog;
  @service currentUser;
  @service messageBus;
  @service modal;
  @service nestedViewCache;
  @service router;
  @service site;
  @service siteSettings;

  @tracked topic;
  @tracked opPost;
  @tracked rootNodes = [];
  @tracked page = 0;
  @tracked rootPageSize = 20;
  @tracked rootWindowStart = 0;
  @tracked rootWindowPages = [];
  @tracked hasMoreRoots = false;
  @tracked rootCount = null;
  @tracked loadingMore = false;
  @tracked sort;
  @tracked effectiveSort;
  @tracked messageBusLastId;
  @tracked postNumber;
  @tracked context = null;
  @tracked contextMode = false;
  @tracked contextChain = null;
  @tracked initialFocusedPath = [];
  @tracked targetPostNumber = null;
  @tracked contextNoAncestors = false;
  @tracked ancestorsTruncated = false;
  @tracked topAncestorPostNumber = null;
  @tracked newRootPostIds = [];
  @tracked editingTopic = false;
  @tracked pinnedPostIds = [];
  @tracked pinnedRootCount = 0;
  // Persisted in the URL across in-topic navigation by design — once a
  // user lands via a consolidated reply notification, browsing within
  // the topic keeps the collapsed view, and the URL is shareable in that
  // state. If we ever want to scope it to entry-only, clear after the
  // initial render in the route.
  @tracked collapseReplies = false;

  // Externalized expansion state: postNumber → { expanded, collapsed }
  // Components read on construction, write on toggle.
  // Persisted across back/forward navigations via NestedViewCache.
  expansionState = new Map();

  // Cache of dynamically loaded children: postNumber → { childNodes, page, hasMore, fetchedFromServer }
  // Populated by NestedPostChildren on every mutation, read on restoration.
  fetchedChildrenCache = new Map();

  // Scroll anchor for cache restoration: { postNumber, offsetFromTop, scrollY? }
  scrollAnchor = null;

  quoteState = new QuoteState();

  // Flat registry of all rendered posts by post_number.
  // Populated by NestedPost components via appEvents so that readPosts
  // can find posts at any depth, not just those in the preloaded tree.
  postRegistry = new Map();
  #latestScrollAnchor = null;
  #loadMorePromise = null;
  #activeJumpToken = null;
  #activeRootRequestCount = 0;
  #rootPageCache = new Map();
  #rootWindowEntries = [];
  #rootWindowKey = null;
  #rootWindowNodesRef = null;
  #rootWindowGeneration = 0;
  #rootWindowIndicesStale = false;
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

  get multiSelect() {
    return this.#topicController.multiSelect;
  }

  get selectedPostsCount() {
    return this.#topicController.selectedPostsCount;
  }

  get newRootPostCount() {
    return this.contextMode ? 0 : this.newRootPostIds.length;
  }

  get hasPreviousRoots() {
    return !this.contextMode && this.rootWindowStart > 0;
  }

  // The server only reports rootCount with the initial page, so fall back to
  // what the active window proves exists rather than assuming a single root.
  get #knownRootTotal() {
    return this.rootCount ?? this.rootWindowStart + this.rootNodes.length;
  }

  get canSelectAll() {
    return this.#nestedSelectablePostIds().some(
      (id) => !this.#topicController.selectedPostIds.includes(id)
    );
  }

  get canDeselectAll() {
    return this.selectedPostsCount > 0;
  }

  get canDeleteSelected() {
    const selectedPosts = this.#topicController.selectedPosts;

    return (
      this.selectedPostsCount > 0 &&
      this.selectedPostsCount === selectedPosts.length &&
      selectedPosts.every((post) => post.can_delete)
    );
  }

  get canMergeTopic() {
    return this.#topicController.canMergeTopic;
  }

  get canChangeOwner() {
    return this.#topicController.canChangeOwner;
  }

  get canMergePosts() {
    return this.#topicController.canMergePosts;
  }

  @bind
  postSelected(post) {
    return this.#topicController.postSelected(post);
  }

  @action
  toggleMultiSelect(event) {
    return this.#topicController.toggleMultiSelect(event);
  }

  @action
  togglePostSelection(post) {
    return this.#topicController.togglePostSelection(post);
  }

  @action
  selectReplies(post) {
    return this.#topicController.selectReplies(post);
  }

  @action
  selectBelow(post) {
    const postIds = this.#visiblePostIdsBelow(post);

    if (postIds.length > 0) {
      this.#topicController._updateSelectedPostIds(postIds);
    }
  }

  @action
  selectAll(event) {
    event?.preventDefault();
    this.#topicController._updateSelectedPostIds(
      this.#nestedSelectablePostIds()
    );
  }

  @action
  deselectAll(event) {
    return this.#topicController.deselectAll(event);
  }

  @action
  deleteSelected() {
    const user = this.currentUser;
    this.dialog.yesNoConfirm({
      message: i18n("post.delete.confirm", {
        count: this.selectedPostsCount,
      }),
      didConfirm: () => {
        Post.deleteMany(this.#topicController.selectedPostIds);
        (this.topic?.postStream?.posts || []).forEach(
          (post) =>
            this.postSelected(post) &&
            post.setDeletedState &&
            post.setDeletedState(user)
        );
        this.toggleMultiSelect();
      },
    });
  }

  @action
  mergePosts() {
    return this.#topicController.mergePosts();
  }

  #visiblePostIdsBelow(post) {
    const viewSelector = this.contextMode
      ? ".nested-context-view"
      : ".nested-view:not(.nested-context-view)";
    const view = document.querySelector(viewSelector);
    if (!view) {
      return [post.id];
    }

    const postIds = Array.from(
      view.querySelectorAll("article[data-post-id]")
    ).map((element) => Number(element.dataset.postId));
    const index = postIds.indexOf(post.id);

    return index === -1 ? [post.id] : postIds.slice(index);
  }

  #nestedSelectablePostIds() {
    return (this.topic?.postStream?.posts || [])
      .map((post) => post.id)
      .filter((id) => id != null);
  }

  @action
  loadMoreRoots() {
    if (!this.hasMoreRoots) {
      return Promise.resolve();
    }
    if (this.loadingMore) {
      return this.#loadMorePromise ?? Promise.resolve();
    }

    const promise = this.#loadMoreRootsImpl().finally(() => {
      // A concurrent caller may have installed a newer in-flight promise in
      // the microtask gap after loadingMore flips false; don't clobber it.
      if (this.#loadMorePromise === promise) {
        this.#loadMorePromise = null;
      }
    });
    this.#loadMorePromise = promise;
    return promise;
  }

  async #loadMoreRootsImpl() {
    this.#ensureRootWindowState();
    const generation = this.#rootWindowGeneration;

    try {
      const nextPage = this.#rootWindowEntries.at(-1).page + 1;
      const entry = await this.#getRootPage(nextPage);
      if (generation !== this.#rootWindowGeneration) {
        return;
      }

      this.#activateRootWindow(
        this.#rootWindowIndicesStale
          ? [entry]
          : [...this.#rootWindowEntries, entry]
      );
      this.#assignSuggestedAndRelated(entry.data);
    } catch (e) {
      popupAjaxError(e);
    }
  }

  @action
  async loadPreviousRoots() {
    if (!this.hasPreviousRoots || this.loadingMore) {
      return;
    }

    this.#ensureRootWindowState();
    const previousPage = this.#rootWindowEntries[0].page - 1;
    if (previousPage < 0) {
      return;
    }

    const generation = this.#rootWindowGeneration;
    try {
      const entry = await this.#getRootPage(previousPage);
      if (generation !== this.#rootWindowGeneration) {
        return;
      }

      this.#activateRootWindow(
        this.#rootWindowIndicesStale
          ? [entry]
          : [entry, ...this.#rootWindowEntries],
        { keep: "start" }
      );
    } catch (error) {
      popupAjaxError(error);
    }
  }

  @action
  changeSort(newSort) {
    if (newSort === this.sort) {
      return;
    }

    const shouldScrollToRoots = !this.contextMode;

    this.router.transitionTo({ queryParams: { sort: newSort } }).then(() => {
      if (shouldScrollToRoots) {
        schedule("afterRender", this, this.#scrollToRoots);
      }
    });
  }

  #scrollToRoots() {
    const roots = document.querySelector(
      ".nested-view:not(.nested-context-view) .nested-view__roots"
    );

    if (!roots) {
      return;
    }

    const controls = document.querySelector(
      ".nested-view:not(.nested-context-view) > .nested-view__controls"
    );
    const controlsHeight = controls?.offsetHeight || 0;
    const rect = roots.getBoundingClientRect();

    window.scrollTo({
      top: window.scrollY + rect.top - headerOffset() - controlsHeight,
    });
  }

  @action
  async jumpToRoot(index) {
    const topicId = this.topic?.id;
    const sort = this.effectiveSort;
    const jumpToken = (this.#activeJumpToken = {});
    const targetIndex = Math.max(
      0,
      Math.min(index, Math.max(this.#knownRootTotal - 1, 0))
    );

    if (!this.#rootWindowContains(targetIndex)) {
      this.#rootWindowGeneration++;
      const unpinnedIndex = Math.max(targetIndex - this.pinnedRootCount, 0);
      const targetPage = Math.floor(unpinnedIndex / this.rootPageSize);
      let result;
      try {
        result = await this.#getRootPage(targetPage);
      } catch (error) {
        popupAjaxError(error);
        return {
          index: this.#nearestLoadedRootIndex(targetIndex),
          reached: false,
        };
      }

      if (
        !result ||
        this.topic?.id !== topicId ||
        this.effectiveSort !== sort ||
        this.#activeJumpToken !== jumpToken
      ) {
        return null;
      }

      if (result.nodes.length === 0) {
        return {
          index: this.#nearestLoadedRootIndex(targetIndex),
          reached: false,
        };
      }

      this.#activateRootWindow([result]);
      this.#assignSuggestedAndRelated(result.data);
    }

    if (
      this.topic?.id !== topicId ||
      this.effectiveSort !== sort ||
      this.#activeJumpToken !== jumpToken
    ) {
      return null;
    }

    const localIndex = targetIndex - this.rootWindowStart;
    if (localIndex < 0 || localIndex >= this.rootNodes.length) {
      return null;
    }

    schedule("afterRender", () => this.#scrollToRootAt(localIndex));
    return { index: targetIndex, reached: targetIndex === index };
  }

  async #requestRootPage(page) {
    this.#activeRootRequestCount++;
    this.loadingMore = true;

    try {
      const query = new URLSearchParams({
        page,
        sort: this.effectiveSort || this.sort || "top",
      });
      const data = await ajax(
        `/n/${this.topic.slug}/${this.topic.id}.json?${query}`
      );

      return {
        data,
        nodes: (data.roots || []).map((root) => this.#processNode(root)),
      };
    } finally {
      this.#activeRootRequestCount--;
      this.loadingMore = this.#activeRootRequestCount > 0;
    }
  }

  async #getRootPage(page) {
    this.#ensureRootWindowState();
    const cached = this.#rootPageCache.get(page);
    // A cached page is a snapshot of replies, votes and deletions as they were
    // when it was fetched, so it is only reused while it is still fresh.
    if (cached && !this.#rootPageExpired(cached)) {
      this.#cacheRootPage(cached);
      return cached;
    }
    if (cached) {
      this.#rootPageCache.delete(page);
    }

    const result = await this.#requestRootPage(page);
    const entry = this.#rootWindowEntry(result, result.data.page ?? page);
    this.#cacheRootPage(entry);
    return entry;
  }

  // A page's absolute start is recorded when it is fetched instead of being
  // re-derived from its page number later: roots inserted live shift the pages
  // already in hand, and only the entries that predate the insert move.
  #rootWindowEntry(result, page) {
    const rootPageSize = result.data.root_page_size || this.rootPageSize;

    return {
      ...result,
      page,
      fetchedAt: Date.now(),
      absoluteStart:
        page === 0 ? 0 : this.pinnedRootCount + page * rootPageSize,
    };
  }

  #rootPageExpired(entry) {
    return (
      entry.fetchedAt != null &&
      Date.now() - entry.fetchedAt > ROOT_PAGE_CACHE_TTL_MS
    );
  }

  // Jumping makes any page cheap to fetch, so the cache is bounded: pages in
  // the active window are always kept, the rest evicted oldest-first.
  #cacheRootPage(entry) {
    this.#rootPageCache.delete(entry.page);
    this.#rootPageCache.set(entry.page, entry);

    const windowPages = new Set(
      this.#rootWindowEntries.map((windowEntry) => windowEntry.page)
    );
    for (const page of this.#rootPageCache.keys()) {
      if (this.#rootPageCache.size <= ROOT_PAGE_CACHE_LIMIT) {
        break;
      }
      if (page !== entry.page && !windowPages.has(page)) {
        this.#rootPageCache.delete(page);
      }
    }
  }

  #ensureRootWindowState() {
    const key = `${this.topic?.id}:${this.effectiveSort || this.sort}`;
    if (
      this.#rootWindowKey === key &&
      this.#rootWindowNodesRef === this.rootNodes &&
      this.#rootWindowEntries.length > 0
    ) {
      return;
    }

    this.#rootWindowKey = key;
    this.#rootPageCache = new Map();
    this.#rootWindowEntries = this.#entriesFromRootWindowPages() || [
      this.#singleRootWindowEntry(),
    ];
    if (
      this.rootWindowPages.length === 0 &&
      this.rootNodes.length >
        this.rootPageSize + (this.page === 0 ? this.pinnedRootCount : 0)
    ) {
      this.#rootWindowIndicesStale = true;
    }
    this.#rootWindowNodesRef = this.rootNodes;
    for (const entry of this.#rootWindowEntries) {
      this.#rootPageCache.set(entry.page, entry);
    }
    this.#rootWindowGeneration++;
  }

  #activateRootWindow(entries, { keep = "end" } = {}) {
    const boundedEntries = this.#dedupeRootWindowEntries(
      keep === "start"
        ? entries.slice(0, ROOT_WINDOW_PAGE_LIMIT)
        : entries.slice(-ROOT_WINDOW_PAGE_LIMIT)
    );
    const firstPage = boundedEntries[0].page;
    const lastEntry = boundedEntries.at(-1);

    this.#rootWindowEntries = boundedEntries;
    this.rootWindowPages = boundedEntries.map((entry) => ({
      page: entry.page,
      nodeCount: entry.nodes.length,
      hasMoreRoots: entry.data.has_more_roots || false,
      rootPageSize: entry.data.root_page_size || this.rootPageSize,
      absoluteStart: entry.absoluteStart,
    }));
    this.rootPageSize = lastEntry.data.root_page_size || this.rootPageSize;
    this.rootWindowStart =
      boundedEntries[0].absoluteStart ??
      (firstPage === 0
        ? 0
        : this.pinnedRootCount + firstPage * this.rootPageSize);
    this.rootNodes = boundedEntries.flatMap((entry) => entry.nodes);
    this.#rootWindowNodesRef = this.rootNodes;
    this.page = lastEntry.page;
    this.hasMoreRoots = lastEntry.data.has_more_roots || false;
    this.#rootWindowIndicesStale = false;
  }

  // Offsets shift whenever roots are added or removed between page fetches, so
  // adjacent pages of the window can overlap. Nodes are keyed on post id when
  // rendered, and a duplicate key breaks the whole list: keep the earliest
  // occurrence and drop the rest.
  #dedupeRootWindowEntries(entries) {
    const seenPostIds = new Set();

    return entries.map((entry) => {
      let leadingDuplicates = 0;
      let foundUniqueNode = false;
      const nodes = entry.nodes.filter((node) => {
        if (seenPostIds.has(node.post.id)) {
          if (!foundUniqueNode) {
            leadingDuplicates++;
          }
          return false;
        }

        foundUniqueNode = true;
        seenPostIds.add(node.post.id);
        return true;
      });

      return {
        ...entry,
        absoluteStart:
          entry.absoluteStart == null
            ? entry.absoluteStart
            : entry.absoluteStart + leadingDuplicates,
        nodes,
      };
    });
  }

  #resetRootWindowState(entry) {
    this.#rootWindowKey = `${this.topic?.id}:${this.effectiveSort || this.sort}`;
    this.#rootPageCache = new Map([[entry.page, entry]]);
    this.#rootWindowEntries = [entry];
    this.#rootWindowGeneration++;
    this.#activateRootWindow([entry]);
  }

  #invalidateRootWindowState() {
    this.#rootWindowKey = null;
    this.#rootPageCache = new Map();
    this.#rootWindowEntries = [];
    this.#rootWindowNodesRef = null;
    this.rootWindowPages = [];
    this.#rootWindowGeneration++;
  }

  #entriesFromRootWindowPages() {
    const descriptors = this.rootWindowPages || [];
    const describedNodeCount = descriptors.reduce(
      (count, descriptor) => count + descriptor.nodeCount,
      0
    );

    if (
      descriptors.length > 0 &&
      describedNodeCount === this.rootNodes.length &&
      descriptors.every(
        (descriptor, index) =>
          descriptor.nodeCount >= 0 &&
          (index === 0 || descriptor.page === descriptors[index - 1].page + 1)
      )
    ) {
      let nodeOffset = 0;
      return descriptors.map((descriptor) => {
        const nodes = this.rootNodes.slice(
          nodeOffset,
          nodeOffset + descriptor.nodeCount
        );
        nodeOffset += descriptor.nodeCount;

        return {
          data: {
            page: descriptor.page,
            root_page_size: descriptor.rootPageSize || this.rootPageSize,
            has_more_roots: descriptor.hasMoreRoots || false,
          },
          nodes,
          page: descriptor.page,
          absoluteStart: descriptor.absoluteStart,
        };
      });
    }

    return null;
  }

  #singleRootWindowEntry() {
    return {
      data: {
        page: this.page,
        root_page_size: this.rootPageSize,
        has_more_roots: this.hasMoreRoots,
      },
      nodes: this.rootNodes,
      page: this.page,
      absoluteStart: this.rootWindowStart,
    };
  }

  #rootWindowContains(index) {
    return (
      !this.#rootWindowIndicesStale &&
      index >= this.rootWindowStart &&
      index < this.rootWindowStart + this.rootNodes.length
    );
  }

  #nearestLoadedRootIndex(targetIndex) {
    if (this.rootNodes.length === 0) {
      return 0;
    }

    return Math.max(
      this.rootWindowStart,
      Math.min(targetIndex, this.rootWindowStart + this.rootNodes.length - 1)
    );
  }

  // Targets the nth root wrapper rather than a post article: roots far from
  // the viewport are cloaked and don't render their [data-post-number]
  // article, but the wrapper always exists with a placeholder height.
  #scrollToRootAt(index) {
    const element = document.querySelectorAll(
      ".nested-view:not(.nested-context-view) .nested-view__roots-window > .nested-post"
    )[index];
    if (!element) {
      return;
    }

    const controls = document.querySelector(
      ".nested-view:not(.nested-context-view) > .nested-view__controls"
    );
    const rect = element.getBoundingClientRect();

    window.scrollTo({
      top:
        window.scrollY +
        rect.top -
        headerOffset() -
        (controls?.offsetHeight || 0),
    });
  }

  @action
  viewFullThread() {
    this.saveToCache();
    this.nestedViewCache.useNextTransition();
    this.router.transitionTo(
      "topic.fromParams",
      this.topic.slug,
      this.topic.id,
      {
        queryParams: { sort: this.sort, context: null },
      }
    );
  }

  @action
  setFocusedPostNumber(postNumber, focusedPath = []) {
    this.postNumber = postNumber;
    this.targetPostNumber = postNumber;
    this.initialFocusedPath = focusedPath;
  }

  @action
  saveScrollPosition(scrollAnchor) {
    this.saveScrollAnchor(scrollAnchor);
  }

  @action
  clearScrollAnchor() {
    this.scrollAnchor = null;
  }

  saveScrollAnchor(scrollAnchor) {
    if (!this.topic || !scrollAnchor) {
      return;
    }

    this.#latestScrollAnchor = scrollAnchor;
    this.#saveScrollAnchorToSession(this.#cacheKey(), scrollAnchor);
  }

  saveToCache(scrollAnchor = this.#latestScrollAnchor) {
    if (!this.topic) {
      return;
    }

    const modelData = {
      topic: this.topic,
      opPost: this.opPost,
      rootNodes: this.rootNodes,
      page: this.page,
      rootPageSize: this.rootPageSize,
      rootWindowStart: this.rootWindowStart,
      rootWindowPages: this.rootWindowPages,
      hasMoreRoots: this.hasMoreRoots,
      rootCount: this.rootCount,
      sort: this.sort,
      effectiveSort: this.effectiveSort,
      messageBusLastId: this.messageBusLastId,
      pinnedPostIds: this.pinnedPostIds,
      pinnedRootCount: this.pinnedRootCount,
      postNumber: this.postNumber,
      context: this.context,
      contextMode: this.contextMode,
      contextChain: this.contextChain,
      initialFocusedPath: this.initialFocusedPath,
      targetPostNumber: this.targetPostNumber,
      contextNoAncestors: this.contextNoAncestors,
      ancestorsTruncated: this.ancestorsTruncated,
      topAncestorPostNumber: this.topAncestorPostNumber,
      newRootPostIds: this.newRootPostIds,
    };

    const cacheKey = this.#cacheKey();

    this.nestedViewCache.save(cacheKey, {
      formatVersion: NESTED_VIEW_CACHE_FORMAT_VERSION,
      modelData: snapshotNestedModelData(modelData),
      expansionState: snapshotExpansionState(this.expansionState),
      fetchedChildrenCache: snapshotFetchedChildrenCache(
        this.fetchedChildrenCache
      ),
      scrollAnchor,
    });

    if (scrollAnchor) {
      this.#saveScrollAnchorToSession(cacheKey, scrollAnchor);
    }
  }

  #cacheKey() {
    return this.nestedViewCache.buildKey(this.topic.id, {
      sort: this.sort,
      post_number: this.postNumber,
      context: this.context ?? undefined,
    });
  }

  #saveScrollAnchorToSession(cacheKey, scrollAnchor) {
    try {
      sessionStorage.setItem(
        `nested-view-scroll:${cacheKey}`,
        JSON.stringify(scrollAnchor)
      );
    } catch {
      // Ignore storage failures; in-memory scroll restoration still works.
    }
  }

  @action
  viewParentContext() {
    this.saveToCache();

    if (this.ancestorsTruncated && this.topAncestorPostNumber) {
      this.router.transitionTo(
        "topic.fromParamsNear",
        this.topic.slug,
        this.topic.id,
        this.topAncestorPostNumber,
        { queryParams: { sort: this.sort } }
      );
    } else {
      this.router.transitionTo(
        "topic.fromParamsNear",
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
  deletePost(post, opts) {
    if (post.post_number === 1) {
      return this.#topicController.deletePost(post, opts);
    }

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
      const topicId = this.topic.id;
      const sort = this.effectiveSort;
      const anchorRootId = this.#visibleRootId();
      const result = await ajax(
        `/n/${this.topic.slug}/${this.topic.id}/pin.json`,
        {
          type: "PUT",
          data: { post_id: post.id },
        }
      );

      this.pinnedPostIds = result.pinned_post_ids || [];
      this.#invalidateRootWindowState();

      const page = await this.#requestRootPage(0);
      if (this.topic?.id !== topicId || this.effectiveSort !== sort) {
        return;
      }

      const entry = this.#rootWindowEntry(page, page.data.page ?? 0);
      this.pinnedPostIds = page.data.pinned_post_ids || this.pinnedPostIds;
      const pinnedIdSet = new Set(this.pinnedPostIds);
      this.pinnedRootCount = page.nodes.filter((node) =>
        pinnedIdSet.has(node.post.id)
      ).length;
      this.rootCount = page.data.root_count ?? this.rootCount;
      this.#resetRootWindowState(entry);
      this.#assignSuggestedAndRelated(page.data);

      // Pinning reorders the whole list, so the window falls back to page zero
      // and the reader's scroll position would otherwise land wherever the
      // shortened document clamps it. Prefer the root they were reading; an
      // unpinned post usually leaves the window entirely, so fall back to the
      // post that moved and then to the top of the roots.
      this.#restorePinScroll([anchorRootId, post.id]);
    } catch (e) {
      popupAjaxError(e);
    }
  }

  #visibleRootId() {
    const roots = document.querySelectorAll(
      ".nested-view:not(.nested-context-view) .nested-view__roots-window > .nested-post"
    );
    const eyeline = headerOffset();

    for (const root of roots) {
      if (root.getBoundingClientRect().bottom > eyeline) {
        return Number(root.dataset.rootId) || null;
      }
    }

    return null;
  }

  #restorePinScroll(candidateRootIds) {
    schedule("afterRender", () => {
      if (this.isDestroying || this.isDestroyed) {
        return;
      }

      for (const rootId of candidateRootIds) {
        const index = rootId
          ? this.rootNodes.findIndex((node) => node.post.id === rootId)
          : -1;
        if (index >= 0) {
          this.#scrollToRootAt(index);
          return;
        }
      }

      this.#scrollToRoots();
    });
  }

  @action
  selectText() {
    const tc = this.#topicController;
    this.#ensurePostInStream(this.quoteState.postId);
    tc.quoteState.copyFrom(this.quoteState);
    return tc.selectText();
  }

  @action
  buildQuoteMarkdown() {
    const tc = this.#topicController;
    this.#ensurePostInStream(this.quoteState.postId);
    tc.quoteState.copyFrom(this.quoteState);
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
          registerPostInTopicPostStream(this.topic, post);
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
  changeNotice(post) {
    return this.#topicController.changeNotice(post);
  }

  @action
  changePostOwner(post) {
    return this.#topicRoute.changeOwner(post);
  }

  @action
  grantBadge(post) {
    return this.#topicRoute.showGrantBadgeModal(post);
  }

  @action
  lockPost(post) {
    return this.#topicController.lockPost(post);
  }

  @action
  unlockPost(post) {
    return this.#topicController.unlockPost(post);
  }

  @action
  permanentlyDeletePost(post) {
    return this.#topicController.permanentlyDeletePost(post);
  }

  @action
  rebakePost(post) {
    return this.#topicController.rebakePost(post);
  }

  @action
  showPagePublish() {
    return this.#topicRoute.showPagePublish();
  }

  @action
  togglePostType(post) {
    return this.#topicController.togglePostType(post);
  }

  @action
  toggleWiki(post) {
    return this.#topicController.toggleWiki(post);
  }

  @action
  unhidePost(post) {
    return this.#topicController.unhidePost(post);
  }

  @action
  showActivityLog() {
    this.modal.show(NestedActivityLog, {
      model: { topic: this.topic, editPost: this.editPost },
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
    this.appEvents.on(
      "nested-replies:scroll-restored",
      this,
      this.#onScrollRestored
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
      this.appEvents.off(
        "nested-replies:scroll-restored",
        this,
        this.#onScrollRestored
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
    const topicId = this.topic?.id;
    if (
      post?.post_number != null &&
      topicId != null &&
      String(post.topic?.id) === String(topicId)
    ) {
      this.topic?.postStream?.storePost(post);
      this.postRegistry.set(post.post_number, post);
    }
  }

  #onPostUnregistered(post) {
    if (
      post?.post_number != null &&
      this.postRegistry.get(post.post_number) === post
    ) {
      this.postRegistry.delete(post.post_number);
    }
  }

  #onScrollRestored() {
    this.scrollAnchor = null;
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
      if (
        this.topic?.id !== topicId ||
        !this.#postBelongsToTopic(postData, topicId)
      ) {
        return;
      }

      if (this.#isActivityLogPost(postData)) {
        this.#notifyActivityChanged(data);
        return;
      }

      if (!this.#isVisibleInTree(postData)) {
        return;
      }

      const replyTo = postData.reply_to_post_number;
      const isRoot = !replyTo || replyTo === 1;

      if (isRoot) {
        if (this.contextMode) {
          return;
        }

        const node = this.#processNode({ ...postData, children: [] });
        if (data.user_id === this.currentUser?.id) {
          this.#incrementRootCount(1);
          this.#insertLiveRoots([node]);
        } else {
          // Not counted yet: the post sits behind the "new replies" button
          // until loadNewRoots makes it reachable.
          this.newRootPostIds = [...this.newRootPostIds, data.id];
        }
      } else {
        const node = this.#processNode({ ...postData, children: [] });
        this.appEvents.trigger("nested-replies:child-created", {
          topicId,
          post: node.post,
          parentPostNumber: this.#visibleParentPostNumber(postData),
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
    return !this.#isActivityLogPost(postData);
  }

  #isActivityLogPost(postData) {
    const postTypes = this.site.post_types;
    if (postData.post_type === postTypes.small_action) {
      return true;
    }
    if (postData.post_type === postTypes.whisper && postData.action_code) {
      return true;
    }
    return false;
  }

  #notifyActivityChanged(data) {
    const topicId = this.topic?.id;
    if (topicId) {
      this.topic = this.store.createRecord("topic", {
        id: topicId,
        has_activity_log: true,
      });
    }
    this.appEvents.trigger("nested-replies:activity-changed", {
      topicId,
      postId: data.id,
      type: data.type,
    });
  }

  #visibleParentPostNumber(postData) {
    const replyTo = postData.reply_to_post_number;
    if (!this.siteSettings.nested_replies_cap_nesting_depth) {
      return replyTo;
    }

    const ancestors = [];
    let postNumber = replyTo;

    while (postNumber && postNumber !== 1) {
      ancestors.unshift(postNumber);
      const post = this.postRegistry.get(postNumber);
      if (!post) {
        return replyTo;
      }
      postNumber = post.reply_to_post_number;
    }

    const maxDepth = this.siteSettings.nested_replies_max_depth;
    return ancestors.length > maxDepth ? ancestors[maxDepth - 1] : replyTo;
  }

  #postBelongsToTopic(postData, topicId = this.topic?.id) {
    return (
      postData?.topic_id != null &&
      String(postData.topic_id) === String(topicId)
    );
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
      if (this.topic?.has_activity_log) {
        this.#notifyActivityChanged(data);
      }
      this.#markPostDeletedLocally(data.id);
      return;
    }

    const topicId = this.topic?.id;
    try {
      const postData = await ajax(`/posts/${data.id}.json`);
      if (
        this.topic?.id !== topicId ||
        !this.#postBelongsToTopic(postData, topicId)
      ) {
        return;
      }

      if (this.#isActivityLogPost(postData)) {
        this.#notifyActivityChanged(data);
        return;
      }

      const existing = [...this.postRegistry.values()].find(
        (p) => p.id === data.id
      );
      if (existing) {
        // Route through the store so Post.munge runs — it rebuilds
        // actions_summary as ActionSummary instances and repopulates
        // actionByName. Without this, flagsAvailable (reads actionByName)
        // and postActionFor (reads actions_summary) drift apart after an
        // "acted" event, which crashes the flag modal on the next submit.
        const updated = this.store.createRecord("post", postData);
        existing.updateFromPost(updated);
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
    if (this.contextMode) {
      this.newRootPostIds = [];
      return;
    }

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
      if (
        result.status === "fulfilled" &&
        this.#postBelongsToTopic(result.value, topicId)
      ) {
        newNodes.push(this.#processNode({ ...result.value, children: [] }));
      }
    }

    if (newNodes.length > 0) {
      this.#incrementRootCount(newNodes.length);
      this.#insertLiveRoots(newNodes);
    }
  }

  #insertLiveRoots(newNodes) {
    const sort = this.effectiveSort || this.sort;

    if (this.rootWindowStart > 0) {
      this.#invalidateRootWindowState();
      if (sort === "new") {
        this.rootWindowStart += newNodes.length;
      } else if (sort !== "old") {
        this.#rootWindowIndicesStale = true;
      }
      return;
    }

    const ids = new Set(newNodes.map((node) => node.post.id));
    const existingNodes = this.rootNodes.filter(
      (node) => !ids.has(node.post.id)
    );
    // Newest-first puts a new root at the top and oldest-first at the very
    // bottom; score-based sorts only know the real position server-side, so
    // show it at the top and stop trusting the window's absolute indices.
    const placeAtEnd = sort === "old" && !this.hasMoreRoots;
    const outsideWindow = sort === "old" && this.hasMoreRoots;
    const positionKnown =
      sort === "new" || placeAtEnd || existingNodes.length === 0;
    if (outsideWindow) {
      this.#invalidateRootWindowState();
      this.#rootWindowIndicesStale = true;
      return;
    }

    const pinnedNodes = existingNodes.slice(0, this.pinnedRootCount);
    const unpinnedNodes = existingNodes.slice(this.pinnedRootCount);
    const combined = placeAtEnd
      ? [...pinnedNodes, ...unpinnedNodes, ...newNodes]
      : [...pinnedNodes, ...newNodes, ...unpinnedNodes];
    // Live roots grow the window past the pages it was built from; one page of
    // headroom bounds a busy topic. Trim the end away from the insertion point
    // rather than dropping the roots that just arrived.
    const capacity =
      this.pinnedRootCount + (ROOT_WINDOW_PAGE_LIMIT + 1) * this.rootPageSize;
    const overflow = Math.max(combined.length - capacity, 0);

    this.rootNodes = placeAtEnd
      ? combined.slice(overflow)
      : combined.slice(0, combined.length - overflow);
    if (placeAtEnd) {
      this.rootWindowStart += overflow;
    }
    this.#absorbLiveRootsIntoWindow({
      atStart: !placeAtEnd,
      insertedCount: newNodes.length,
    });
    if (!positionKnown) {
      this.#rootWindowIndicesStale = true;
    }
    this.hasMoreRoots = placeAtEnd
      ? false
      : overflow > 0 ||
        this.rootCount == null ||
        this.rootWindowStart + this.rootNodes.length < this.rootCount;
  }

  // The live roots land inside the rendered window rather than replacing it, so
  // the page they fall into grows by their count. Server page boundaries shift
  // by the same amount, which the next fetch resolves by de-duplicating.
  #absorbLiveRootsIntoWindow({ atStart, insertedCount }) {
    const descriptors = (this.rootWindowPages || []).map((descriptor) => ({
      ...descriptor,
    }));
    if (descriptors.length === 0) {
      descriptors.push({
        page: this.page,
        nodeCount: 0,
        hasMoreRoots: this.hasMoreRoots,
        rootPageSize: this.rootPageSize,
        absoluteStart: this.rootWindowStart,
      });
    }

    if (atStart) {
      // Roots inserted at the head push every page already in hand further
      // along the global axis; the page they joined still starts where it did.
      for (const descriptor of descriptors.slice(1)) {
        if (descriptor.absoluteStart != null) {
          descriptor.absoluteStart += insertedCount;
        }
      }
    }

    let excess =
      descriptors.reduce(
        (count, descriptor) => count + descriptor.nodeCount,
        0
      ) - this.rootNodes.length;

    if (excess <= 0) {
      (atStart ? descriptors[0] : descriptors.at(-1)).nodeCount -= excess;
      excess = 0;
    } else {
      // Walk in from the trimmed end, shrinking pages until the descriptors
      // account for exactly what is rendered.
      for (const descriptor of atStart
        ? [...descriptors].reverse()
        : descriptors) {
        const removed = Math.min(descriptor.nodeCount, excess);
        descriptor.nodeCount -= removed;
        if (!atStart && descriptor.absoluteStart != null) {
          descriptor.absoluteStart += removed;
        }
        excess -= removed;
        if (excess === 0) {
          break;
        }
      }
    }

    this.#invalidateRootWindowState();
    const kept = descriptors.filter((descriptor) => descriptor.nodeCount > 0);
    if (excess !== 0 || kept.length === 0) {
      this.#rootWindowIndicesStale = true;
      return;
    }

    this.rootWindowPages = kept;
  }

  #incrementRootCount(count) {
    if (this.rootCount != null) {
      this.rootCount += count;
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
