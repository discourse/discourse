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
import PostAvatar from "discourse/components/post/avatar";
import lazyHash from "discourse/helpers/lazy-hash";
import getURL from "discourse/lib/get-url";
import DiscourseURL from "discourse/lib/url";
import PostStreamViewportTracker from "discourse/modifiers/post-stream-viewport-tracker";
import { and, gt, includes, not } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import DConditionalLoadingSpinner from "discourse/ui-kit/d-conditional-loading-spinner";
import DLoadMore from "discourse/ui-kit/d-load-more";
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

export default class Nested extends Component {
  @service appEvents;
  @service currentUser;
  @service header;
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
  #scrollAttempts = 0;
  #maxScrollAttempts = 20;
  #nextTimer = null;
  #retryTimer = null;
  #highlightTimer = null;
  #lastScrollKey = null;

  constructor() {
    super(...arguments);
    this.applyInitialFocusedPath();
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
      return 2;
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
    return this.args.initialFocusedPath?.map((node) => node.post?.id).join(":");
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
  focusPath(path) {
    if (!this.site.mobileView) {
      return;
    }

    if (!this.isMobileFocused) {
      this.mobileReturnAnchor = this.scrollAnchorForPath(path);
    }

    this.focusDirection =
      path.length >= this.focusedPath.length ? "forward" : "back";
    this.focusedPath = path;
    this.#replaceURLForFocusedPath(path);
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
    if (!this.site.mobileView || !this.args.initialFocusedPath?.length) {
      return;
    }

    const key = this.initialFocusedPathKey;
    if (!key || key === this.#initialFocusedPathKey) {
      return;
    }

    this.#initialFocusedPathKey = key;
    this.focusDirection = "forward";
    this.focusedPath = this.args.initialFocusedPath;
  }

  #replaceURLForFocusedPath(path) {
    const postNumber = path.at(-1)?.post?.post_number || null;
    this.args.setFocusedPostNumber?.(postNumber);
    DiscourseURL.replaceState(this.#nestedURL(postNumber));
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
        ".nested-view > .nested-view__controls"
      );
      const rect = target.getBoundingClientRect();
      window.scrollTo({
        top:
          window.scrollY +
          rect.top -
          (this.header.headerOffset || 0) -
          (controls?.offsetHeight || 0),
        behavior: "smooth",
      });
    } else if (this.#scrollAttempts < this.#maxScrollAttempts) {
      this.#scrollAttempts++;
      this.#retryTimer = schedule("afterRender", this, this.#scrollToTarget);
    }
  }

  #nestedURL(postNumber = null) {
    let path = `/n/${this.args.topic.slug}/${this.args.topic.id}`;
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
      {{didUpdate this.scheduleTargetScroll @targetPostNumber @rootNodes}}
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
                  <PostAvatar @post={{ancestorNode.post}} @size="small" />
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
                @forceExpanded={{true}}
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

      <NestedFloatingActions
        @topic={{@topic}}
        @replyAction={{fn @replyToPost @opPost 0}}
      />
    </div>
  </template>
}
