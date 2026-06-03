import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { helper } from "@ember/component/helper";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import MoreTopics from "discourse/components/more-topics";
import PluginOutlet from "discourse/components/plugin-outlet";
import PostAvatar from "discourse/components/post/avatar";
import lazyHash from "discourse/helpers/lazy-hash";
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

  @tracked cloakAbove = 0;
  @tracked cloakBelow = 0;
  @tracked focusDirection = "forward";
  @tracked focusedPath = [];
  @tracked mobileReturnAnchor = null;
  viewportTracker = new PostStreamViewportTracker();

  constructor() {
    super(...arguments);
    this.appEvents.on("keyboard:move-selection", this, this.maybeLoadMoreRoots);
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
      "nested-replies:scroll-restored",
      this,
      this.clearMobileReturnAnchor
    );
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
    return this.isMobileFocused ? "nested-view -mobile-focused" : "nested-view";
  }

  get mobileFocusClass() {
    return `nested-view__mobile-focus --${this.focusDirection}`;
  }

  get collapseFromDepth() {
    if (this.args.collapseReplies) {
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
  }

  @action
  returnToAncestor(index) {
    this.focusPath(this.focusedPath.slice(0, index + 1));
  }

  @action
  clearFocus() {
    this.focusDirection = "back";
    this.mobileReturnAnchor ??= this.scrollAnchorForPath(this.focusedPath);
    this.focusedPath = [];
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

  <template>
    <div
      class={{this.viewClass}}
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
        <div class={{this.mobileFocusClass}}>
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
          {{#each @rootNodes key="post.id" as |node index|}}
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
