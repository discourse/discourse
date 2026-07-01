import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { helper } from "@ember/component/helper";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import { cancel, next, schedule } from "@ember/runloop";
import { service } from "@ember/service";
import MoreTopics from "discourse/components/more-topics";
import PluginOutlet from "discourse/components/plugin-outlet";
import lazyHash from "discourse/helpers/lazy-hash";
import getURL, { withoutPrefix } from "discourse/lib/get-url";
import DiscourseURL from "discourse/lib/url";
import PostStreamViewportTracker from "discourse/modifiers/post-stream-viewport-tracker";
import { and, gt, includes, not } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import DConditionalLoadingSpinner from "discourse/ui-kit/d-conditional-loading-spinner";
import DLoadMore from "discourse/ui-kit/d-load-more";
import dAvatar from "discourse/ui-kit/helpers/d-avatar";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";
import NestedFloatingActions from "./nested/floating-actions";
import NestedHeader from "./nested/header";
import NestedOp from "./nested/op";
import NestedPost from "./nested/post";
import NestedSortSelector from "./nested/sort-selector";
import NestedTopicActions from "./nested/topic-actions";

const postExcerpt = helper(([post]) => {
  const element = document.createElement("div");
  element.innerHTML = post.cooked ?? "";

  return element.textContent?.replace(/\s+/g, " ").trim();
});

// Depth is zero-based; depth 3 matches the server's root preload depth.
const MOBILE_ROOT_VIEW_COLLAPSE_DEPTH = 3;
const STORED_SCROLL_ANCHORS = Object.create(null);

export default class Nested extends Component {
  @service appEvents;
  @service currentUser;
  @service header;
  @service router;
  @service screenTrack;
  @service site;
  @service siteSettings;

  @tracked cloakAbove = 0;
  @tracked cloakBelow = 0;
  @tracked focusDirection = "forward";
  @tracked focusedPath = [];
  @tracked mobileReturnAnchor = null;
  viewportTracker = new PostStreamViewportTracker();
  #initialFocusedPathKey = null;
  #focusedPathsByPostNumber = new Map();
  #scrollAttempts = 0;
  #maxScrollAttempts = 20;
  #nextTimer = null;
  #retryTimer = null;
  #highlightTimer = null;
  #lastScrollKey = null;
  #restoringStoredScroll = false;
  #onPopstate = () => {
    this.#restoringStoredScroll = true;
    next(this, this.syncFocusFromURL);
  };
  #onScroll = () => this.persistScrollAnchor();
  #onPageHide = () => this.persistScrollAnchor();

  constructor() {
    super(...arguments);
    this.#restoringStoredScroll = Boolean(this.#loadStoredScrollAnchor());
    this.applyInitialFocusedPath();
    window.addEventListener("popstate", this.#onPopstate);
    window.addEventListener("scroll", this.#onScroll, { passive: true });
    document.addEventListener("scroll", this.#onScroll, { passive: true });
    window.addEventListener("pagehide", this.#onPageHide);
    this.router.on("routeWillChange", this.persistScrollAnchor);
    this.appEvents.on("keyboard:move-selection", this, this.maybeLoadMoreRoots);
    this.appEvents.on(
      "nested:scroll-to-target",
      this,
      this.forceScheduleTargetScroll
    );
    this.appEvents.on(
      "nested-replies:scroll-restored",
      this,
      this.clearMobileReturnAnchor
    );
  }

  willDestroy() {
    super.willDestroy(...arguments);
    this.appEvents.off(
      "keyboard:move-selection",
      this,
      this.maybeLoadMoreRoots
    );
    this.appEvents.off(
      "nested:scroll-to-target",
      this,
      this.forceScheduleTargetScroll
    );
    this.appEvents.off(
      "nested-replies:scroll-restored",
      this,
      this.clearMobileReturnAnchor
    );
    cancel(this.#nextTimer);
    cancel(this.#retryTimer);
    clearTimeout(this.#highlightTimer);
    this.persistScrollAnchor();
    window.removeEventListener("popstate", this.#onPopstate);
    window.removeEventListener("scroll", this.#onScroll);
    document.removeEventListener("scroll", this.#onScroll);
    window.removeEventListener("pagehide", this.#onPageHide);
    this.router.off("routeWillChange", this.persistScrollAnchor);
    this.viewportTracker.destroy();
  }

  @action
  maybeLoadMoreRoots({ selectedArticle, articles }) {
    if (!this.args.hasMoreRoots || this.args.loadingMore) {
      return;
    }
    if (selectedArticle === articles[articles.length - 1]) {
      this.args.loadMoreRoots?.();
    }
  }

  get emptyPath() {
    return [];
  }

  get isMobileFocused() {
    return this.site.mobileView && this.focusedPath.length > 0;
  }

  get viewClass() {
    return [
      "nested-view",
      this.args.contextMode ? "nested-context-view" : null,
      this.isMobileFocused ? "-mobile-focused" : null,
    ]
      .filter(Boolean)
      .join(" ");
  }

  get showContextBanner() {
    return this.args.contextMode && !this.site.mobileView;
  }

  get showParentContextLink() {
    return this.args.contextNoAncestors || this.args.ancestorsTruncated;
  }

  get mobileFocusClass() {
    return `nested-view__mobile-focus --${this.focusDirection}`;
  }

  get collapseFromDepth() {
    if (this.args.collapseReplies) {
      if (this.args.contextMode) {
        return this.args.rootNodes?.[0]?.post?.post_number ===
          this.args.targetPostNumber
          ? 1
          : null;
      }

      if (this.isMobileFocused) {
        return this.focusedPath.length > 1 ? null : 1;
      }

      return 0;
    }

    if (this.site.mobileView) {
      return MOBILE_ROOT_VIEW_COLLAPSE_DEPTH;
    }

    return null;
  }

  get rootScrollAnchor() {
    return this.mobileReturnAnchor || this.args.scrollAnchor;
  }

  get focusedNode() {
    return this.focusedPath.at(-1);
  }

  get focusedNodes() {
    return this.focusedNode ? [this.focusedNode] : [];
  }

  get ancestorPath() {
    return this.focusedPath.slice(0, -1);
  }

  get initialFocusedPathKey() {
    return this.#focusedPathKey(this.args.initialFocusedPath);
  }

  get targetScrollKey() {
    return `${this.args.targetPostNumber}:${this.args.rootNodes?.[0]?._renderKey}`;
  }

  @action
  setCloakingBoundaries(above, below) {
    this.cloakAbove = above;
    this.cloakBelow = below;
  }

  @action
  focusPath(path, returnAnchor) {
    if (!this.site.mobileView) {
      return;
    }

    if (!this.isMobileFocused) {
      this.mobileReturnAnchor =
        returnAnchor ||
        this.findScrollAnchor() ||
        this.scrollAnchorForPath(path);
      this.args.saveScrollPosition?.(this.mobileReturnAnchor);
      this.#saveStoredScrollAnchor(this.mobileReturnAnchor, null);
    }

    this.focusDirection =
      path.length >= this.focusedPath.length ? "forward" : "back";
    this.focusedPath = path;
    this.#registerFocusedPath(path);
    this.#pushURLForFocusedPath(path);
  }

  @action
  returnToAncestor(index) {
    this.focusPath(this.focusedPath.slice(0, index + 1));
  }

  @action
  clearFocus() {
    if (this.args.contextMode) {
      this.args.viewFullThread?.();
      return;
    }

    this.focusDirection = "back";
    this.mobileReturnAnchor ??= this.scrollAnchorForPath(this.focusedPath);
    this.focusedPath = [];
    this.#replaceURLForFocusedPath([]);
  }

  @action
  clearMobileReturnAnchor() {
    this.mobileReturnAnchor = null;
    this.args.clearScrollAnchor?.();
  }

  @action
  captureScrollAnchor() {
    return this.findScrollAnchor();
  }

  @action
  persistScrollAnchor() {
    if (this.isDestroying || this.isDestroyed || this.#restoringStoredScroll) {
      return;
    }

    const anchor = this.findScrollAnchor();
    if (anchor) {
      this.args.saveScrollPosition?.(anchor);
      this.#saveStoredScrollAnchor(
        anchor,
        this.isMobileFocused ? null : this.args.postNumber
      );
    }
  }

  @action
  restoreStoredScrollAnchor() {
    const anchor = this.args.scrollAnchor || this.#loadStoredScrollAnchor();
    if (!anchor) {
      return;
    }

    this.#restoreScrollAnchorAfterRender(anchor);
  }

  #restoreScrollAnchorAfterRender(anchor) {
    this.#restoringStoredScroll = true;
    schedule("afterRender", () => {
      this.#restoreScrollAnchor(anchor);
      for (const delay of [50, 150, 300, 600, 1000]) {
        setTimeout(() => this.#restoreScrollAnchor(anchor), delay);
      }
      setTimeout(() => (this.#restoringStoredScroll = false), 1250);
    });
  }

  #restoreScrollAnchor(anchor) {
    if (Number.isFinite(anchor.scrollY)) {
      window.scrollTo(0, anchor.scrollY);
      return;
    }

    const article = document.querySelector(
      `.nested-post [data-post-number="${anchor.postNumber}"]`
    );
    const element = article?.closest(".nested-post") || article;
    if (element) {
      const rect = element.getBoundingClientRect();
      window.scrollTo(0, window.scrollY + rect.top - anchor.offsetFromTop);
    }
  }

  #saveStoredScrollAnchor(anchor, postNumber = this.args.postNumber) {
    const key = this.#scrollAnchorKey(postNumber);
    this.#storedScrollAnchors[key] = anchor;

    try {
      sessionStorage.setItem(key, JSON.stringify(anchor));
    } catch {
      // Ignore storage failures; module-level in-memory cache still works.
    }
  }

  #loadStoredScrollAnchor(postNumber = this.args.postNumber) {
    const key = this.#scrollAnchorKey(postNumber);
    const cached = this.#storedScrollAnchors[key];
    if (cached) {
      return cached;
    }

    try {
      const value = sessionStorage.getItem(key);
      return value ? JSON.parse(value) : null;
    } catch {
      return null;
    }
  }

  get #storedScrollAnchors() {
    return STORED_SCROLL_ANCHORS;
  }

  #scrollAnchorKey(postNumber = this.args.postNumber) {
    const parts = [this.args.topic.id];
    if (this.args.sort) {
      parts.push(`s=${this.args.sort}`);
    }
    if (postNumber) {
      parts.push(`p=${postNumber}`);
    }
    if (this.args.contextNoAncestors) {
      parts.push("c=0");
    }
    return `nested-view-scroll:${parts.join(":")}`;
  }

  findScrollAnchor() {
    const articles = document.querySelectorAll(
      ".nested-view__roots .nested-post [data-post-number]"
    );
    let best = null;
    let bestDistance = Infinity;

    for (const article of articles) {
      const postElement = article.closest(".nested-post") || article;
      const rect = postElement.getBoundingClientRect();
      const distance = Math.abs(rect.top);
      if (distance < bestDistance) {
        bestDistance = distance;
        best = {
          postNumber: Number(article.dataset.postNumber),
          offsetFromTop: rect.top,
          scrollY: window.scrollY,
        };
      }
    }

    return best;
  }

  scrollAnchorForPath(path) {
    const rootNode = path?.[0];
    const postNumber = rootNode?.post?.post_number;
    if (!postNumber) {
      return null;
    }

    const postElement = document.querySelector(
      `.nested-view [data-post-number="${postNumber}"]`
    );
    const element = postElement?.closest(".nested-post") || postElement;
    if (!element) {
      return { postNumber, offsetFromTop: this.header.headerOffset };
    }

    return {
      postNumber,
      offsetFromTop: element.getBoundingClientRect().top,
      scrollY: window.scrollY,
    };
  }

  @action
  scrollMobileFocusIntoContext(element) {
    if (!this.isMobileFocused || this.isDestroying || this.isDestroyed) {
      return;
    }

    const ancestorRows = element.querySelectorAll(
      ".nested-view__mobile-ancestor"
    );
    const target =
      ancestorRows[ancestorRows.length - 1] ||
      element.querySelector(".nested-view__mobile-focus-back");
    if (!target) {
      return;
    }

    const rect = target.getBoundingClientRect();
    window.scrollTo({
      top: window.scrollY + rect.top - this.#stickyHeaderBottom(),
      behavior: "auto",
    });
  }

  #stickyHeaderBottom() {
    const headerWrap = document.querySelector(".d-header-wrap");
    return Math.max(0, headerWrap?.getBoundingClientRect().bottom || 0);
  }

  @action
  applyInitialFocusedPath() {
    if (!this.site.mobileView) {
      return;
    }

    const key = this.initialFocusedPathKey;

    if (!this.args.initialFocusedPath?.length) {
      this.#initialFocusedPathKey = key;
      if (this.focusedPath.length > 0) {
        this.focusDirection = "back";
        this.focusedPath = [];
      }
      return;
    }

    if (key === this.#initialFocusedPathKey) {
      return;
    }

    this.#initialFocusedPathKey = key;
    this.focusDirection = "forward";
    this.focusedPath = this.args.initialFocusedPath;
    this.#registerFocusedPath(this.focusedPath);
  }

  #focusedPathKey(path) {
    return (path || [])
      .map((node) => `${node._renderKey || node.post?.id}:${node.post?.id}`)
      .join(":");
  }

  @action
  syncFocusFromURL() {
    if (this.isDestroying || this.isDestroyed || !this.site.mobileView) {
      return;
    }

    const postNumber = this.#postNumberFromCurrentURL();
    if (postNumber === undefined) {
      return;
    }

    if (!postNumber) {
      const storedAnchor = this.#loadStoredScrollAnchor();
      const anchor =
        this.mobileReturnAnchor ||
        storedAnchor ||
        (this.focusedPath.length > 0
          ? this.scrollAnchorForPath(this.focusedPath)
          : null);

      this.args.setFocusedPostNumber?.(null, []);
      if (this.focusedPath.length > 0) {
        this.focusDirection = "back";
      }
      this.mobileReturnAnchor = anchor;
      this.focusedPath = [];

      if (anchor) {
        this.#restoreScrollAnchorAfterRender(anchor);
      } else {
        this.#restoringStoredScroll = false;
      }
      return;
    }

    const path = this.#focusedPathsByPostNumber.get(postNumber);
    if (!path) {
      this.#restoringStoredScroll = false;
      return;
    }

    this.args.setFocusedPostNumber?.(postNumber, path);
    this.focusDirection =
      path.length >= this.focusedPath.length ? "forward" : "back";
    this.focusedPath = path;
    this.#restoringStoredScroll = false;
  }

  #pushURLForFocusedPath(path) {
    const postNumber = path.at(-1)?.post?.post_number || null;
    this.args.setFocusedPostNumber?.(postNumber, path);
    const url = this.#nestedURL(postNumber);

    if (this.#currentURLMatches(url)) {
      return;
    }

    DiscourseURL.pushState(url);
  }

  #replaceURLForFocusedPath(path) {
    const postNumber = path.at(-1)?.post?.post_number || null;
    this.args.setFocusedPostNumber?.(postNumber, path);
    const url = this.#nestedURL(postNumber);

    if (this.#currentURLMatches(url)) {
      return;
    }

    DiscourseURL.replaceState(url);
  }

  #registerFocusedPath(path) {
    path.forEach((node, index) => {
      const postNumber = node.post?.post_number;
      if (postNumber) {
        this.#focusedPathsByPostNumber.set(
          postNumber,
          path.slice(0, index + 1)
        );
      }
    });
  }

  #postNumberFromCurrentURL() {
    const path = withoutPrefix(window.location.pathname);
    const match = /^\/t\/[^/]+\/(\d+)(?:\/(\d+))?/.exec(path);
    if (!match || String(match[1]) !== String(this.args.topic.id)) {
      return undefined;
    }

    return match[2] ? Number(match[2]) : null;
  }

  #currentURLMatches(url) {
    const current = withoutPrefix(
      `${window.location.pathname}${window.location.search}`
    );
    const target = withoutPrefix(url);

    return current === target;
  }

  @action
  scheduleTargetScroll() {
    this.#scheduleTargetScroll();
  }

  @action
  forceScheduleTargetScroll() {
    this.#scheduleTargetScroll({ force: true });
  }

  #scheduleTargetScroll({ force = false } = {}) {
    if (!this.args.targetPostNumber || this.isMobileFocused) {
      return;
    }

    const scrollKey = this.targetScrollKey;
    if (!force && scrollKey === this.#lastScrollKey) {
      return;
    }

    this.#lastScrollKey = scrollKey;
    cancel(this.#nextTimer);
    cancel(this.#retryTimer);
    clearTimeout(this.#highlightTimer);
    this.#scrollAttempts = 0;
    this.#nextTimer = next(this, this.#scrollToTarget);
  }

  #scrollToTarget() {
    if (this.isDestroying || this.isDestroyed) {
      return;
    }

    const postNumber = this.args.targetPostNumber;
    const target = document.querySelector(
      `.nested-view [data-post-number="${postNumber}"]`
    );

    if (target) {
      const postEl = target.closest(".nested-post");
      if (postEl) {
        postEl.classList.add("nested-post--highlighted");
        this.#highlightTimer = setTimeout(
          () => postEl.classList.remove("nested-post--highlighted"),
          2000
        );
      }

      const controls = document.querySelector(
        ".nested-view:not(.nested-context-view) > .nested-view__controls"
      );
      const banner = document.querySelector(
        ".nested-context-view > .nested-context-view__banner"
      );
      const rect = target.getBoundingClientRect();
      window.scrollTo({
        top:
          window.scrollY +
          rect.top -
          (this.header.headerOffset || 0) -
          (controls?.offsetHeight || 0) -
          (banner?.offsetHeight || 0),
        behavior: "smooth",
      });
    } else if (this.#scrollAttempts < this.#maxScrollAttempts) {
      this.#scrollAttempts++;
      this.#retryTimer = schedule("afterRender", this, this.#scrollToTarget);
    }
  }

  #nestedURL(postNumber = null) {
    let path = `/t/${this.args.topic.slug}/${this.args.topic.id}`;
    if (postNumber) {
      path += `/${postNumber}`;
    }

    const params = new URLSearchParams();
    const defaultSort = this.siteSettings.nested_replies_default_sort || "top";
    if (this.args.sort && this.args.sort !== defaultSort) {
      params.set("sort", this.args.sort);
    }
    if (this.args.collapseReplies) {
      params.set("collapse_replies", "true");
    }

    const query = params.toString();
    return getURL(query ? `${path}?${query}` : path);
  }

  <template>
    <div
      class={{this.viewClass}}
      {{didInsert this.scheduleTargetScroll}}
      {{didInsert this.restoreStoredScrollAnchor}}
      {{didUpdate this.scheduleTargetScroll @targetPostNumber @rootNodes}}
      {{didUpdate this.restoreStoredScrollAnchor @scrollAnchor}}
      {{didUpdate this.applyInitialFocusedPath @initialFocusedPath}}
      {{this.viewportTracker.setup
        eyeline=false
        headerOffset=this.header.headerOffset
        screenTrack=this.screenTrack
        setCloakingBoundaries=this.setCloakingBoundaries
        topicId=@topic.id
      }}
    >
      <NestedHeader
        @topic={{@topic}}
        @editingTopic={{@editingTopic}}
        @buffered={{@buffered}}
        @showCategoryChooser={{@showCategoryChooser}}
        @canEditTags={{@canEditTags}}
        @minimumRequiredTags={{@minimumRequiredTags}}
        @finishedEditingTopic={{@finishedEditingTopic}}
        @cancelEditingTopic={{@cancelEditingTopic}}
        @topicCategoryChanged={{@topicCategoryChanged}}
        @topicTagsChanged={{@topicTagsChanged}}
        @startEditingTopic={{@startEditingTopic}}
      />

      <PluginOutlet
        @name="topic-above-post-stream"
        @connectorTagName="div"
        @outletArgs={{lazyHash model=@topic}}
      />

      {{#if this.isMobileFocused}}
        <div
          class={{this.mobileFocusClass}}
          {{didInsert this.scrollMobileFocusIntoContext}}
          {{didUpdate this.scrollMobileFocusIntoContext this.focusedPath}}
        >
          <button
            type="button"
            class="nested-view__mobile-focus-back"
            {{on "click" this.clearFocus}}
          >
            {{dIcon "chevron-left"}}
            <span>{{i18n "nested_replies.all_replies"}}</span>
          </button>

          {{#if this.ancestorPath.length}}
            <nav
              class="nested-view__mobile-ancestors"
              aria-label={{i18n "nested_replies.focused_path"}}
            >
              {{#each this.ancestorPath as |ancestorNode index|}}
                <button
                  type="button"
                  class="nested-view__mobile-ancestor"
                  data-test-nested-mobile-ancestor={{ancestorNode.post.post_number}}
                  aria-label={{i18n
                    "nested_replies.return_to_branch"
                    username=ancestorNode.post.username
                  }}
                  {{on "click" (fn this.returnToAncestor index)}}
                >
                  {{dIcon "chevron-left"}}
                  <span
                    class="nested-view__mobile-ancestor-avatar"
                    aria-hidden="true"
                  >
                    {{! PostAvatar renders a user link; keep this avatar non-interactive inside the ancestor button. }}
                    {{dAvatar
                      ancestorNode.post
                      imageSize="small"
                      hideTitle=true
                    }}
                  </span>
                  <span class="nested-view__mobile-ancestor-meta">
                    <span
                      class="nested-view__mobile-ancestor-username"
                    >{{ancestorNode.post.username}}</span>
                    <span class="nested-view__mobile-ancestor-excerpt">
                      {{postExcerpt ancestorNode.post}}
                    </span>
                  </span>
                </button>
              {{/each}}
            </nav>
          {{/if}}

          {{#each this.focusedNodes key="post.id" as |focusedNode|}}
            <div class="nested-view__mobile-focused-branch">
              <NestedPost
                @post={{focusedNode.post}}
                @children={{focusedNode.children}}
                @topic={{@topic}}
                @depth={{0}}
                @path={{this.ancestorPath}}
                @sort={{@sort}}
                @replyToPost={{@replyToPost}}
                @editPost={{@editPost}}
                @deletePost={{@deletePost}}
                @recoverPost={{@recoverPost}}
                @showFlags={{@showFlags}}
                @showHistory={{@showHistory}}
                @changeNotice={{@changeNotice}}
                @changePostOwner={{@changePostOwner}}
                @grantBadge={{@grantBadge}}
                @lockPost={{@lockPost}}
                @unlockPost={{@unlockPost}}
                @permanentlyDeletePost={{@permanentlyDeletePost}}
                @rebakePost={{@rebakePost}}
                @showPagePublish={{@showPagePublish}}
                @togglePostType={{@togglePostType}}
                @toggleWiki={{@toggleWiki}}
                @unhidePost={{@unhidePost}}
                @expansionState={{@expansionState}}
                @fetchedChildrenCache={{@fetchedChildrenCache}}
                @scrollAnchor={{@scrollAnchor}}
                @registerPost={{this.viewportTracker.registerPost}}
                @getCloakingData={{this.viewportTracker.getCloakingData}}
                @cloakAbove={{this.cloakAbove}}
                @cloakBelow={{this.cloakBelow}}
                @collapseFromDepth={{this.collapseFromDepth}}
                @focusPost={{this.focusPath}}
                @captureScrollAnchor={{this.captureScrollAnchor}}
                @forceExpanded={{true}}
                @multiSelect={{@multiSelect}}
                @togglePostSelection={{@togglePostSelection}}
                @selectReplies={{@selectReplies}}
                @selectBelow={{@selectBelow}}
                @postSelected={{@postSelected}}
              />
            </div>
          {{/each}}
        </div>
      {{else}}
        <NestedOp
          @post={{@opPost}}
          @topic={{@topic}}
          @editPost={{@editPost}}
          @showHistory={{@showHistory}}
          @replyToPost={{@replyToPost}}
          @changeNotice={{@changeNotice}}
          @changePostOwner={{@changePostOwner}}
          @deletePost={{@deletePost}}
          @grantBadge={{@grantBadge}}
          @lockPost={{@lockPost}}
          @unlockPost={{@unlockPost}}
          @permanentlyDeletePost={{@permanentlyDeletePost}}
          @rebakePost={{@rebakePost}}
          @showPagePublish={{@showPagePublish}}
          @togglePostType={{@togglePostType}}
          @toggleWiki={{@toggleWiki}}
          @unhidePost={{@unhidePost}}
          @showPostMenu={{true}}
          @registerPost={{this.viewportTracker.registerPost}}
          @multiSelect={{@multiSelect}}
          @togglePostSelection={{@togglePostSelection}}
          @selectReplies={{@selectReplies}}
          @selectBelow={{@selectBelow}}
          @postSelected={{@postSelected}}
        />

        {{#if this.currentUser}}
          <NestedTopicActions @topic={{@topic}} />
        {{/if}}

        <div class="nested-view__controls">
          <div class="nested-view__controls-left">
            <NestedSortSelector @current={{@sort}} @onChange={{@changeSort}} />
          </div>

          <div class="nested-view__controls-right">
            {{#if @topic.has_activity_log}}
              <DButton
                class="btn-flat nested-view__activity-link"
                @action={{@showActivityLog}}
                @label="nested_replies.activity_log.link"
              />
            {{/if}}
          </div>
        </div>

        {{#if this.showContextBanner}}
          <div class="nested-context-view__banner">
            <span class="nested-context-view__banner-icon">{{dIcon
                "nested-thread"
              }}</span>
            <span class="nested-context-view__banner-text">{{i18n
                "nested_replies.context.banner"
              }}</span>
            <div class="nested-context-view__nav">
              <DButton
                class="btn-default btn-small nested-context-view__full-thread"
                @action={{@viewFullThread}}
                @icon="arrow-left"
                @translatedLabel={{i18n
                  "nested_replies.context.view_full_topic"
                }}
              />
              {{#if this.showParentContextLink}}
                <DButton
                  class="btn-default btn-small nested-context-view__parent-context"
                  @action={{@viewParentContext}}
                  @icon="arrow-up"
                  @translatedLabel={{i18n
                    "nested_replies.context.view_parent_context"
                  }}
                />
              {{/if}}
            </div>
          </div>
        {{/if}}

        {{#if (gt @newRootPostCount 0)}}
          <div class="nested-view__new-replies">
            <DButton
              class="btn-primary nested-view__new-replies-btn"
              @action={{@loadNewRoots}}
              @translatedLabel={{i18n
                "nested_replies.new_replies"
                count=@newRootPostCount
              }}
            />
          </div>
        {{/if}}

        <div class="nested-view__roots">
          {{#each @rootNodes key="_renderKey" as |node index|}}
            <NestedPost
              @post={{node.post}}
              @children={{node.children}}
              @topic={{@topic}}
              @depth={{0}}
              @path={{this.emptyPath}}
              @sort={{@sort}}
              @isPinned={{includes @pinnedPostIds node.post.id}}
              @replyToPost={{@replyToPost}}
              @editPost={{@editPost}}
              @deletePost={{@deletePost}}
              @recoverPost={{@recoverPost}}
              @showFlags={{@showFlags}}
              @showHistory={{@showHistory}}
              @changeNotice={{@changeNotice}}
              @changePostOwner={{@changePostOwner}}
              @grantBadge={{@grantBadge}}
              @lockPost={{@lockPost}}
              @unlockPost={{@unlockPost}}
              @permanentlyDeletePost={{@permanentlyDeletePost}}
              @rebakePost={{@rebakePost}}
              @showPagePublish={{@showPagePublish}}
              @togglePostType={{@togglePostType}}
              @toggleWiki={{@toggleWiki}}
              @unhidePost={{@unhidePost}}
              @expansionState={{@expansionState}}
              @fetchedChildrenCache={{@fetchedChildrenCache}}
              @scrollAnchor={{this.rootScrollAnchor}}
              @registerPost={{this.viewportTracker.registerPost}}
              @getCloakingData={{this.viewportTracker.getCloakingData}}
              @cloakAbove={{this.cloakAbove}}
              @cloakBelow={{this.cloakBelow}}
              @collapseFromDepth={{this.collapseFromDepth}}
              @focusPost={{this.focusPath}}
              @captureScrollAnchor={{this.captureScrollAnchor}}
              @multiSelect={{@multiSelect}}
              @togglePostSelection={{@togglePostSelection}}
              @selectReplies={{@selectReplies}}
              @selectBelow={{@selectBelow}}
              @postSelected={{@postSelected}}
            />
            <PluginOutlet
              @name="nested-roots-between"
              @outletArgs={{lazyHash topic=@topic index=index}}
            />
          {{else}}
            <div class="nested-view__empty">
              {{i18n "nested_replies.no_replies"}}
            </div>
          {{/each}}
        </div>

        <DConditionalLoadingSpinner @condition={{@loadingMore}} />

        <DLoadMore
          @action={{@loadMoreRoots}}
          @enabled={{@hasMoreRoots}}
          @isLoading={{@loadingMore}}
        />
      {{/if}}

      <PluginOutlet
        @name="topic-above-footer-buttons"
        @connectorTagName="div"
        @outletArgs={{lazyHash model=@topic}}
      />

      <PluginOutlet
        @name="topic-area-bottom"
        @connectorTagName="div"
        @outletArgs={{lazyHash model=@topic}}
      />

      {{#unless this.isMobileFocused}}
        <NestedFloatingActions
          @topic={{@topic}}
          @replyAction={{fn @replyToPost @opPost 0}}
        />
      {{/unless}}

      {{#if (and (not this.isMobileFocused) (not @hasMoreRoots))}}
        <PluginOutlet
          @name="topic-above-suggested"
          @connectorTagName="div"
          @outletArgs={{lazyHash model=@topic}}
        />

        <MoreTopics @topic={{@topic}} />

        <PluginOutlet
          @name="topic-below-suggested"
          @connectorTagName="div"
          @outletArgs={{lazyHash model=@topic}}
        />
      {{/if}}

      <PluginOutlet
        @name="topic-navigation-bottom"
        @connectorTagName="div"
        @outletArgs={{lazyHash model=@topic}}
      />

    </div>
  </template>
}
