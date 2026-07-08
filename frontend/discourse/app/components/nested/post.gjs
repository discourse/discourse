import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { getOwner } from "@ember/owner";
import { cancel, scheduleOnce } from "@ember/runloop";
import { service } from "@ember/service";
import { modifier } from "ember-modifier";
import ShareTopicModal from "discourse/components/modal/share-topic";
import NestedRepliesExpandButton from "discourse/components/nested-replies-expand-button";
import PluginOutlet from "discourse/components/plugin-outlet";
import PostAvatar from "discourse/components/post/avatar";
import PostCookedHtml from "discourse/components/post/cooked-html";
import PostLinks from "discourse/components/post/links";
import PostMenu from "discourse/components/post/menu";
import PostMetaData from "discourse/components/post/meta-data";
import PostNotice from "discourse/components/post/notice";
import lazyHash from "discourse/helpers/lazy-hash";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { isTesting } from "discourse/lib/environment";
import getURL, { getAbsoluteURL } from "discourse/lib/get-url";
import postActionFeedback from "discourse/lib/post-action-feedback";
import { nativeShare } from "discourse/lib/pwa-utils";
import { clipboardCopy } from "discourse/lib/utilities";
import { and, not, or } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";
import nestedPostUrl from "../../lib/nested-post-url";
import processNode from "../../lib/process-node";
import NestedPostChildren from "./post-children";

export default class NestedPost extends Component {
  @service appEvents;
  @service capabilities;
  @service currentUser;
  @service modal;
  @service site;
  @service siteSettings;
  @service store;

  @tracked expanded;
  @tracked lineHighlighted = false;
  @tracked collapsed;
  @tracked showDeletedContent = false;
  @tracked showIgnoredContent = false;
  @tracked loadingIgnoredContent = false;
  @tracked loadingReplies = false;
  restoreScroll = modifier((element) => {
    const anchor = this.args.scrollAnchor;
    if (anchor?.postNumber !== this.args.post.post_number) {
      return;
    }

    const anchorKey = [
      anchor.postNumber,
      anchor.scrollY ?? "",
      anchor.offsetFromTop ?? "",
    ].join(":");
    if (anchorKey === this.#restoredScrollAnchorKey) {
      return;
    }
    this.#restoredScrollAnchorKey = anchorKey;

    if (Number.isFinite(anchor.scrollY)) {
      window.scrollTo(0, anchor.scrollY);
    } else {
      const rect = element.getBoundingClientRect();
      window.scrollTo(0, window.scrollY + rect.top - anchor.offsetFromTop);
    }

    // Defer the event to avoid backtracking re-render errors during the render phase
    Promise.resolve().then(() => {
      this.appEvents.trigger("nested-replies:scroll-restored");
    });
  });
  #restoredScrollAnchorKey = null;

  #postRegistered = false;
  #postRegistrationTimer;

  @tracked _childWasCreated = false;

  constructor() {
    super(...arguments);

    const cached = this.args.expansionState?.get(this.args.post.post_number);
    if (cached !== undefined) {
      this.expanded = cached.expanded;
      this.collapsed = cached.collapsed;
    } else {
      const wouldExpand =
        (this.args.children?.length ?? 0) > 0 ||
        this.args.post.deleted_post_placeholder === true ||
        this.args.post.ignored_post_placeholder === true;

      // collapseFromDepth is the URL-driven cutoff (set by the parent view —
      // 0 for root view, 1 for context view). At/below it, the post renders
      // but its children start hidden behind an "Expand X replies" button.
      if (
        this.args.collapseFromDepth != null &&
        this.args.depth >= this.args.collapseFromDepth
      ) {
        this.expanded = false;
      } else {
        this.expanded = wouldExpand;
      }
      this.collapsed = false;
    }

    this.appEvents.on(
      "nested-replies:child-created",
      this,
      this._onChildCreated
    );
    this.#postRegistrationTimer = scheduleOnce(
      "afterRender",
      this,
      this.#registerPost
    );
  }

  willDestroy() {
    super.willDestroy(...arguments);
    cancel(this.#postRegistrationTimer);
    this.appEvents.off(
      "nested-replies:child-created",
      this,
      this._onChildCreated
    );

    if (this.#postRegistered) {
      this.appEvents.trigger(
        "nested-replies:post-unregistered",
        this.args.post
      );
    }
  }

  #registerPost() {
    if (this.isDestroying || this.isDestroyed) {
      return;
    }

    this.#postRegistered = true;
    this.appEvents.trigger("nested-replies:post-registered", this.args.post);
  }

  _onChildCreated({ topicId, post: childPost, parentPostNumber, isOwnPost }) {
    if (
      String(topicId) !== String(this.args.topic?.id) ||
      parentPostNumber !== this.args.post.post_number
    ) {
      return;
    }

    const post = this.args.post;
    post.set("direct_reply_count", (post.direct_reply_count || 0) + 1);
    post.set("total_descendant_count", (post.total_descendant_count || 0) + 1);
    this._childWasCreated = true;

    if (!this.expanded) {
      this.expanded = true;
      this.collapsed = false;
      this.args.expansionState?.set(this.args.post.post_number, {
        expanded: true,
        collapsed: false,
      });
    }

    if (isOwnPost && this.mobileFocusEnabled) {
      this.args.focusPost(this.childPathWithNewChild(childPost));
    }
  }

  get isRoot() {
    return this.args.depth === 0;
  }

  get cloakingData() {
    if (!this.isRoot || !this.args.getCloakingData) {
      return { active: false };
    }
    return this.args.getCloakingData(this.args.post, {
      above: this.args.cloakAbove,
      below: this.args.cloakBelow,
    });
  }

  get depthClass() {
    return `--depth-${this.args.depth}`;
  }

  get isMobile() {
    return this.site.mobileView;
  }

  get canCreatePost() {
    return this.currentUser && this.args.topic?.details?.can_create_post;
  }

  get hasReplies() {
    return (
      this._childWasCreated ||
      (this.args.post.direct_reply_count || 0) > 0 ||
      (this.args.children?.length ?? 0) > 0
    );
  }

  get replyCount() {
    const count =
      this.args.post.total_descendant_count ||
      this.args.post.direct_reply_count ||
      this.args.children?.length ||
      0;
    return this._childWasCreated ? Math.max(count, 1) : count;
  }

  get atMaxDepth() {
    return this.args.depth >= this.siteSettings.nested_replies_max_depth;
  }

  get isDeletedPlaceholder() {
    return this.args.post.deleted_post_placeholder === true;
  }

  get isIgnoredPlaceholder() {
    return this.args.post.ignored_post_placeholder === true;
  }

  get renderIgnoredPlaceholder() {
    return this.isIgnoredPlaceholder && !this.showIgnoredContent;
  }

  get showContinueThread() {
    return (
      this.atMaxDepth &&
      this.hasReplies &&
      !this.siteSettings.nested_replies_cap_nesting_depth
    );
  }

  get showDepthLine() {
    return !this.hasReplies || !this.atMaxDepth || this.showContinueThread;
  }

  get depthLineCollapsed() {
    return this.hasReplies && !this.expanded;
  }

  get showDepthLineIcon() {
    return !this.hasReplies || this.expanded;
  }

  get showExpandRepliesButton() {
    return this.hasReplies && !this.effectiveExpanded && !this.atMaxDepth;
  }

  get childPath() {
    return [
      ...(this.args.path || []),
      { post: this.args.post, children: this.args.children || [] },
    ];
  }

  childPathWithChildren(children) {
    return [
      ...(this.args.path || []),
      { post: this.args.post, children: children || [] },
    ];
  }

  childPathWithNewChild(childPost) {
    const children = this.args.children || [];
    const hasChild = children.some(
      (node) =>
        node.post?.id === childPost?.id ||
        node.post?.post_number === childPost?.post_number
    );

    return [
      ...(this.args.path || []),
      {
        post: this.args.post,
        children: hasChild
          ? children
          : [{ post: childPost, children: [] }, ...children],
      },
    ];
  }

  get mobileFocusEnabled() {
    return this.site.mobileView && this.args.focusPost;
  }

  get childDepth() {
    return this.args.depth + 1;
  }

  get effectiveExpanded() {
    return this.args.forceExpanded || this.expanded;
  }

  get effectiveCollapsed() {
    return !this.args.forceExpanded && this.collapsed;
  }

  get isOP() {
    return this.args.post.user_id === this.args.topic?.user_id;
  }

  get selected() {
    return this.args.multiSelect && this.args.postSelected?.(this.args.post);
  }

  get contextUrl() {
    return getURL(
      `/t/${this.args.topic.slug}/${this.args.topic.id}/${this.args.post.post_number}?context=0`
    );
  }

  get expandLabel() {
    return i18n("nested_replies.collapsed_replies", {
      count: this.replyCount,
    });
  }

  get collapsedBarLabel() {
    return this.hasReplies
      ? this.expandLabel
      : i18n("nested_replies.collapsed_post");
  }

  get depthLineLabel() {
    if (this.site.mobileView && !this.args.forceExpanded) {
      return i18n("nested_replies.collapse");
    }

    if (this.depthLineCollapsed) {
      return this.expandLabel;
    }

    return i18n("nested_replies.collapse");
  }

  @action
  toggleExpanded() {
    if (!this.hasReplies) {
      this.collapsed = !this.collapsed;
      this.lineHighlighted = false;
      this.args.expansionState?.set(this.args.post.post_number, {
        expanded: this.expanded,
        collapsed: this.collapsed,
      });
      return;
    }

    if (this.expanded) {
      this.expanded = false;
      this.collapsed = true;
      this.lineHighlighted = false;
    } else {
      this.expanded = true;
      this.collapsed = false;
    }
    this.args.expansionState?.set(this.args.post.post_number, {
      expanded: this.expanded,
      collapsed: this.collapsed,
    });
  }

  collapsePost() {
    if (this.hasReplies) {
      this.expanded = false;
    }

    this.collapsed = true;
    this.lineHighlighted = false;
    this.args.expansionState?.set(this.args.post.post_number, {
      expanded: this.expanded,
      collapsed: this.collapsed,
    });
  }

  async childrenForMobileFocus() {
    const cached = this.args.fetchedChildrenCache?.get(
      this.args.post.post_number
    );
    if (cached) {
      return cached.childNodes;
    }

    if ((this.args.children?.length ?? 0) > 0 || !this.hasReplies) {
      return this.args.children || [];
    }

    this.loadingReplies = true;
    try {
      const query = new URLSearchParams({
        sort: this.args.sort || "top",
        depth: this.childDepth,
      });
      const data = await ajax(
        `/n/${this.args.topic.slug}/${this.args.topic.id}/children/${this.args.post.post_number}.json?${query}`
      );
      if (this.isDestroying || this.isDestroyed) {
        return null;
      }

      const childNodes = (data.children || []).map((child) =>
        processNode(this.store, this.args.topic, child)
      );
      this.args.fetchedChildrenCache?.set(this.args.post.post_number, {
        childNodes,
        page: data.page,
        hasMore: data.has_more || false,
        fetchedFromServer: true,
      });
      return childNodes;
    } catch (e) {
      if (!(this.isDestroying || this.isDestroyed)) {
        popupAjaxError(e);
      }
      return null;
    } finally {
      if (!(this.isDestroying || this.isDestroyed)) {
        this.loadingReplies = false;
      }
    }
  }

  @action
  async handleReplies() {
    if (this.loadingReplies) {
      return;
    }

    if (this.mobileFocusEnabled) {
      const returnAnchor = this.args.captureScrollAnchor?.();
      const children = await this.childrenForMobileFocus();
      if (children && !(this.isDestroying || this.isDestroyed)) {
        this.args.focusPost(this.childPathWithChildren(children), returnAnchor);
      }
      return;
    }

    this.toggleExpanded();
  }

  @action
  handleDepthLine() {
    if (this.site.mobileView && !this.args.forceExpanded) {
      this.collapsePost();
      return;
    }

    this.toggleExpanded();
  }

  @action
  toggleDeletedContent() {
    this.showDeletedContent = !this.showDeletedContent;
  }

  @action
  async revealIgnoredContent() {
    if (this.showIgnoredContent || this.loadingIgnoredContent) {
      return;
    }

    const post = this.args.post;
    try {
      this.loadingIgnoredContent = true;
      const result = await ajax(`/posts/${post.id}/cooked.json`);
      post.set("cooked", result.cooked);
      this.showIgnoredContent = true;
    } catch (e) {
      popupAjaxError(e);
    } finally {
      this.loadingIgnoredContent = false;
    }
  }

  @action
  highlightLine() {
    if (!this.site.mobileView) {
      this.lineHighlighted = true;
    }
  }

  @action
  unhighlightLine() {
    this.lineHighlighted = false;
  }

  get nestedShareUrl() {
    return nestedPostUrl(this.args.topic, this.args.post.post_number);
  }

  @action
  copyLink() {
    if (this.site.mobileView) {
      return this.share();
    }

    const post = this.args.post;
    const postId = post.id;

    let actionCallback = () =>
      clipboardCopy(getAbsoluteURL(this.nestedShareUrl));

    if (isTesting()) {
      actionCallback = () => {};
    }

    postActionFeedback({
      postId,
      actionClass: "post-action-menu__copy-link",
      messageKey: "post.controls.link_copied",
      actionCallback,
      errorCallback: () => this.share(),
    });
  }

  @action
  async share() {
    const post = this.args.post;

    try {
      await nativeShare(this.capabilities, {
        url: getAbsoluteURL(this.nestedShareUrl),
      });
    } catch {
      const topic = this.args.topic;
      this.modal.show(ShareTopicModal, {
        model: { category: topic.category, topic, post },
      });
    }
  }

  @action
  async toggleLike() {
    const post = this.args.post;
    const likeAction = post.likeAction;

    if (likeAction?.canToggle) {
      try {
        await likeAction.togglePromise(post);
      } catch (e) {
        popupAjaxError(e);
      }
    }
  }

  @action
  togglePostSelection() {
    return this.args.togglePostSelection?.(this.args.post);
  }

  @action
  selectReplies() {
    return this.args.selectReplies?.(this.args.post);
  }

  @action
  selectBelow() {
    return this.args.selectBelow?.(this.args.post);
  }

  @action
  showLogin() {
    getOwner(this).lookup("route:application").send("showLogin");
  }

  <template>
    <div
      class={{dConcatClass
        "nested-post"
        this.depthClass
        (if @parentLineHighlighted "--parent-line-highlighted")
        (if this.effectiveCollapsed "nested-post--collapsed")
        (if @isPinned "nested-post--pinned")
        (if @post.isWhisper "nested-post--whisper")
        (if
          (or @post.isModeratorAction (and @post.isWarning @post.firstPost))
          "post--moderator moderator"
        )
        (if @post.hidden "nested-post--hidden post--hidden post-hidden")
        (if (or @post.deleted @post.user_deleted) "nested-post--deleted")
        (if this.cloakingData.active "nested-post--cloaked")
        (if this.selected "selected")
      }}
      style={{this.cloakingData.style}}
      {{this.restoreScroll}}
      {{! At depth 0, register wrapper with cloaking observer (captures full subtree height).
          At deeper depths, register as trackOnly (viewport tracking only, no cloaking). }}
      {{@registerPost @post trackOnly=(not this.isRoot)}}
    >
      {{#unless this.cloakingData.active}}
        {{#if @collapseParent}}
          <button
            type="button"
            class="nested-post__parent-line-btn"
            {{on "click" @collapseParent}}
            {{on "mouseenter" @highlightParentLine}}
            {{on "mouseleave" @unhighlightParentLine}}
            aria-label={{i18n "nested_replies.collapse_parent"}}
          ></button>
        {{/if}}
        <div class="nested-post__gutter">
          {{#if this.isDeletedPlaceholder}}
            <div class="nested-post__placeholder-avatar">
              {{dIcon "trash-can"}}
            </div>
          {{else if this.renderIgnoredPlaceholder}}
            <button
              type="button"
              class="nested-post__placeholder-avatar nested-post__placeholder-avatar--reveal"
              data-post-number={{@post.post_number}}
              aria-label={{i18n "nested_replies.toggle_ignored_content"}}
              disabled={{this.loadingIgnoredContent}}
              {{on "click" this.revealIgnoredContent}}
            >
              {{#if this.loadingIgnoredContent}}
                {{dIcon "spinner" class="fa-spin"}}
              {{else}}
                {{dIcon "far-eye-slash"}}
              {{/if}}
            </button>
          {{else}}
            <PostAvatar @post={{@post}} @size="small" />
          {{/if}}
          {{#if (and this.showDepthLine (not this.effectiveCollapsed))}}
            <button
              type="button"
              class={{dConcatClass
                "nested-post__depth-line"
                (if this.lineHighlighted "nested-post__depth-line--highlighted")
                (unless this.hasReplies "nested-post__depth-line--leaf")
                (if
                  this.depthLineCollapsed "nested-post__depth-line--collapsed"
                )
              }}
              {{on "click" this.handleDepthLine}}
              {{on "mouseenter" this.highlightLine}}
              {{on "mouseleave" this.unhighlightLine}}
              aria-label={{this.depthLineLabel}}
            >
              {{#if this.showDepthLineIcon}}
                <span class="nested-post__depth-line-icon">
                  {{dIcon "discourse-circle-minus"}}
                </span>
              {{/if}}
            </button>
          {{/if}}
        </div>
        <div class="nested-post__main">
          {{#if this.effectiveCollapsed}}
            <button
              type="button"
              class="nested-post__collapsed-bar"
              data-post-number={{@post.post_number}}
              {{on "click" this.toggleExpanded}}
            >
              {{dIcon "discourse-circle-plus"}}
              {{#if this.isDeletedPlaceholder}}
                <span class="nested-post__collapsed-username">{{i18n
                    "nested_replies.deleted_post_placeholder"
                  }}</span>
              {{else if this.renderIgnoredPlaceholder}}
                <span class="nested-post__collapsed-username">{{i18n
                    "nested_replies.ignored_post_placeholder"
                  }}</span>
              {{else}}
                <span
                  class="nested-post__collapsed-username"
                >{{@post.username}}</span>
              {{/if}}
              <span
                class="nested-post__collapsed-separator"
                aria-hidden="true"
              >&middot;</span>
              <span
                class="nested-post__collapsed-reply-count"
              >{{this.collapsedBarLabel}}</span>
            </button>
          {{else if this.isDeletedPlaceholder}}
            <div
              class="nested-post__placeholder nested-post__placeholder--deleted"
              data-post-number={{@post.post_number}}
            >
              <div class="nested-post__placeholder-actions">
                <span class="nested-post__placeholder-label">{{i18n
                    "nested_replies.deleted_post_placeholder"
                  }}</span>
                {{#if this.currentUser.staff}}
                  <DButton
                    class="btn-flat toggle-deleted-content"
                    @action={{this.toggleDeletedContent}}
                    @icon={{if
                      this.showDeletedContent
                      "far-eye-slash"
                      "far-eye"
                    }}
                    @ariaLabel="post.controls.view_deleted"
                  />
                {{/if}}
                {{#if @post.can_recover}}
                  <DButton
                    class="btn-flat recover"
                    @action={{fn @recoverPost @post}}
                    @icon="arrow-rotate-left"
                    @ariaLabel="post.controls.undelete"
                  />
                {{/if}}
              </div>
              {{#if this.showDeletedContent}}
                <div class="nested-post__placeholder-reveal">
                  <div class="nested-post__placeholder-reveal-header">
                    <PostAvatar @post={{@post}} @size="small" />
                    <PostMetaData @post={{@post}} />
                  </div>
                  <PostCookedHtml @post={{@post}} />
                </div>
              {{/if}}
            </div>
          {{else if this.renderIgnoredPlaceholder}}
            <div
              class="nested-post__placeholder nested-post__placeholder--ignored"
              data-post-number={{@post.post_number}}
            >
              <div class="nested-post__placeholder-actions">
                <span class="nested-post__placeholder-label">{{i18n
                    "nested_replies.ignored_post_placeholder"
                  }}</span>
              </div>
            </div>
          {{else}}
            {{#let
              (lazyHash post=@post nestedReplyView=true)
              as |postOutletArgs|
            }}
              <PluginOutlet @name="post-article" @outletArgs={{postOutletArgs}}>
                <article
                  class="nested-post__article boxed"
                  data-post-id={{@post.id}}
                  data-post-number={{@post.post_number}}
                  {{@registerPost @post trackOnly=true}}
                >
                  <PluginOutlet
                    @name="post-article-content"
                    @outletArgs={{postOutletArgs}}
                  >
                    {{#if (PostNotice.shouldRender @post this.siteSettings)}}
                      <PostNotice @post={{@post}} />
                    {{/if}}
                    <div class="nested-post__header">
                      <PluginOutlet
                        @name="post-metadata"
                        @outletArgs={{postOutletArgs}}
                      >
                        <PostMetaData
                          @post={{@post}}
                          @editPost={{fn @editPost @post}}
                          @multiSelect={{@multiSelect}}
                          @selected={{this.selected}}
                          @selectBelow={{this.selectBelow}}
                          @selectReplies={{this.selectReplies}}
                          @showHistory={{fn @showHistory @post}}
                          @togglePostSelection={{this.togglePostSelection}}
                        />
                      </PluginOutlet>
                      {{#if this.isOP}}
                        <span class="nested-post__op-badge">{{i18n
                            "nested_replies.op_badge"
                          }}</span>
                      {{/if}}
                      {{#if @isPinned}}
                        <span class="nested-post__pinned-badge">{{i18n
                            "nested_replies.pinned_reply"
                          }}</span>
                      {{/if}}
                    </div>
                    <div class="nested-post__content regular">
                      <PluginOutlet
                        @name="post-content-cooked-html"
                        @outletArgs={{postOutletArgs}}
                      >
                        <PostCookedHtml @post={{@post}} />
                      </PluginOutlet>
                    </div>
                    <section class="nested-post__menu post-menu-area clearfix">
                      <PostMenu
                        @post={{@post}}
                        @nestedReplyView={{true}}
                        @canCreatePost={{this.canCreatePost}}
                        @copyLink={{this.copyLink}}
                        @deletePost={{fn @deletePost @post}}
                        @editPost={{fn @editPost @post}}
                        @recoverPost={{fn @recoverPost @post}}
                        @replyToPost={{fn @replyToPost @post @depth}}
                        @share={{this.share}}
                        @showFlags={{fn @showFlags @post}}
                        @changeNotice={{fn @changeNotice @post}}
                        @changePostOwner={{fn @changePostOwner @post}}
                        @grantBadge={{fn @grantBadge @post}}
                        @lockPost={{fn @lockPost @post}}
                        @unlockPost={{fn @unlockPost @post}}
                        @permanentlyDeletePost={{fn
                          @permanentlyDeletePost
                          @post
                        }}
                        @rebakePost={{fn @rebakePost @post}}
                        @showPagePublish={{@showPagePublish}}
                        @togglePostType={{fn @togglePostType @post}}
                        @toggleWiki={{fn @toggleWiki @post}}
                        @unhidePost={{fn @unhidePost @post}}
                        @toggleLike={{this.toggleLike}}
                        @toggleReplies={{unless
                          this.atMaxDepth
                          this.handleReplies
                        }}
                        @repliesShown={{if
                          this.atMaxDepth
                          true
                          this.effectiveExpanded
                        }}
                        @showLogin={{this.showLogin}}
                      />
                    </section>
                    {{#if this.showExpandRepliesButton}}
                      <NestedRepliesExpandButton
                        @replyCount={{this.replyCount}}
                        @disabled={{this.loadingReplies}}
                        @isLoading={{this.loadingReplies}}
                        @onClick={{this.handleReplies}}
                      />
                    {{/if}}
                    <PluginOutlet
                      @name="post-links"
                      @outletArgs={{postOutletArgs}}
                    >
                      <PostLinks @post={{@post}} />
                    </PluginOutlet>
                  </PluginOutlet>
                  {{#if this.showContinueThread}}
                    <div class="nested-post__controls">
                      <a
                        href={{this.contextUrl}}
                        class="nested-post__continue-link"
                      >
                        {{i18n "nested_replies.continue_thread"}}
                      </a>
                    </div>
                  {{/if}}
                </article>
              </PluginOutlet>
            {{/let}}
          {{/if}}

          {{#if
            (and
              this.effectiveExpanded
              (not this.effectiveCollapsed)
              (not this.atMaxDepth)
            )
          }}
            <NestedPostChildren
              @topic={{@topic}}
              @parentPostNumber={{@post.post_number}}
              @preloadedChildren={{@children}}
              @directReplyCount={{@post.direct_reply_count}}
              @totalDescendantCount={{@post.total_descendant_count}}
              @depth={{@depth}}
              @path={{this.childPath}}
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
              @collapseParent={{this.toggleExpanded}}
              @highlightParentLine={{this.highlightLine}}
              @unhighlightParentLine={{this.unhighlightLine}}
              @parentLineHighlighted={{this.lineHighlighted}}
              @expansionState={{@expansionState}}
              @fetchedChildrenCache={{@fetchedChildrenCache}}
              @scrollAnchor={{@scrollAnchor}}
              @registerPost={{@registerPost}}
              @collapseFromDepth={{@collapseFromDepth}}
              @focusPost={{@focusPost}}
              @captureScrollAnchor={{@captureScrollAnchor}}
              @multiSelect={{@multiSelect}}
              @togglePostSelection={{@togglePostSelection}}
              @selectReplies={{@selectReplies}}
              @selectBelow={{@selectBelow}}
              @postSelected={{@postSelected}}
            />
          {{/if}}
        </div>
      {{/unless}}
    </div>
  </template>
}
