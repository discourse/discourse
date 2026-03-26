import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { getOwner } from "@ember/owner";
import { service } from "@ember/service";
import { modifier } from "ember-modifier";
import ShareTopicModal from "discourse/components/modal/share-topic";
import PostAvatar from "discourse/components/post/avatar";
import PostCookedHtml from "discourse/components/post/cooked-html";
import PostMenu from "discourse/components/post/menu";
import PostMetaData from "discourse/components/post/meta-data";
import concatClass from "discourse/helpers/concat-class";
import icon from "discourse/helpers/d-icon";
import { isTesting } from "discourse/lib/environment";
import getURL, { getAbsoluteURL } from "discourse/lib/get-url";
import postActionFeedback from "discourse/lib/post-action-feedback";
import { nativeShare } from "discourse/lib/pwa-utils";
import { clipboardCopy } from "discourse/lib/utilities";
import { and, not, or } from "discourse/truth-helpers";
import { i18n } from "discourse-i18n";
import nestedPostUrl from "../lib/nested-post-url";
import NestedPostChildren from "./nested-post-children";

export default class NestedPost extends Component {
  @service appEvents;
  @service capabilities;
  @service currentUser;
  @service modal;
  @service site;
  @service siteSettings;

  @tracked expanded;
  @tracked lineHighlighted = false;
  @tracked collapsed;

  restoreScroll = modifier((element) => {
    const anchor = this.args.scrollAnchor;
    if (anchor?.postNumber !== this.args.post.post_number) {
      return;
    }
    const rect = element.getBoundingClientRect();
    window.scrollTo(0, window.scrollY + rect.top - anchor.offsetFromTop);
  });

  @tracked _childWasCreated = false;

  constructor() {
    super(...arguments);

    const cached = this.args.expansionState?.get(this.args.post.post_number);
    if (cached !== undefined) {
      this.expanded = cached.expanded;
      this.collapsed = cached.collapsed;
    } else {
      this.expanded =
        ((this.args.children?.length ?? 0) > 0 ||
          this.args.post.deleted_post_placeholder === true) &&
        !this.args.defaultCollapsed;
      this.collapsed = false;
    }

    this.appEvents.on(
      "nested-replies:child-created",
      this,
      this._onChildCreated
    );
    this.appEvents.trigger("nested-replies:post-registered", this.args.post);
  }

  willDestroy() {
    super.willDestroy(...arguments);
    this.appEvents.off(
      "nested-replies:child-created",
      this,
      this._onChildCreated
    );
    this.appEvents.trigger("nested-replies:post-unregistered", this.args.post);
  }

  _onChildCreated({ parentPostNumber }) {
    if (parentPostNumber !== this.args.post.post_number) {
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

  get isDeepMobile() {
    return this.site.mobileView && this.args.depth >= 4;
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

  get showContinueThread() {
    return (
      this.atMaxDepth &&
      this.hasReplies &&
      !this.siteSettings.nested_replies_cap_nesting_depth
    );
  }

  get showDepthLine() {
    return this.hasReplies && (!this.atMaxDepth || this.showContinueThread);
  }

  get isOP() {
    return this.args.post.user_id === this.args.topic?.user_id;
  }

  get contextUrl() {
    return getURL(
      `/n/${this.args.topic.slug}/${this.args.topic.id}/${this.args.post.post_number}?context=0`
    );
  }

  get expandLabel() {
    return i18n("nested_replies.collapsed_replies", {
      count: this.replyCount,
    });
  }

  @action
  toggleExpanded() {
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
      const topic = post.topic;
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
      await likeAction.togglePromise(post);
    }
  }

  @action
  showLogin() {
    getOwner(this).lookup("route:application").send("showLogin");
  }

  <template>
    <div
      class={{concatClass
        "nested-post"
        this.depthClass
        (if this.isMobile "--mobile")
        (if this.isDeepMobile "--deep")
        (if @parentLineHighlighted "--parent-line-highlighted")
        (if this.collapsed "nested-post--collapsed")
        (if @isPinned "nested-post--pinned")
        (if @post.isWhisper "nested-post--whisper")
        (if (or @post.deleted @post.user_deleted) "nested-post--deleted")
        (if this.cloakingData.active "nested-post--cloaked")
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
          {{#unless this.isMobile}}
            {{#if this.isDeletedPlaceholder}}
              <div class="nested-post__deleted-avatar-placeholder">
                {{icon "trash-can"}}
              </div>
            {{else}}
              <PostAvatar @post={{@post}} @size="small" />
            {{/if}}
          {{/unless}}
          {{#if (and this.showDepthLine (not this.collapsed))}}
            <button
              type="button"
              class={{concatClass
                "nested-post__depth-line"
                (if this.lineHighlighted "nested-post__depth-line--highlighted")
                (unless this.expanded "nested-post__depth-line--collapsed")
              }}
              {{on "click" this.toggleExpanded}}
              {{on "mouseenter" this.highlightLine}}
              {{on "mouseleave" this.unhighlightLine}}
              aria-label={{if
                this.expanded
                (i18n "nested_replies.collapse")
                this.expandLabel
              }}
            >
              {{#if this.expanded}}
                <span class="nested-post__depth-line-icon">
                  {{icon "nested-circle-minus"}}
                </span>
              {{/if}}
            </button>
          {{/if}}
        </div>
        <div class="nested-post__main">
          {{#if this.collapsed}}
            <button
              type="button"
              class="nested-post__collapsed-bar"
              data-post-number={{@post.post_number}}
              {{on "click" this.toggleExpanded}}
            >
              {{icon "nested-circle-plus"}}
              {{#if this.isDeletedPlaceholder}}
                <span class="nested-post__collapsed-username">{{i18n
                    "nested_replies.deleted_post_placeholder"
                  }}</span>
              {{else}}
                <span
                  class="nested-post__collapsed-username"
                >{{@post.username}}</span>
              {{/if}}
              <span class="nested-post__collapsed-separator">&middot;</span>
              <span
                class="nested-post__collapsed-reply-count"
              >{{this.expandLabel}}</span>
            </button>
          {{else if this.isDeletedPlaceholder}}
            <div
              class="nested-post__deleted-placeholder"
              data-post-number={{@post.post_number}}
            >
              <span class="nested-post__deleted-label">{{i18n
                  "nested_replies.deleted_post_placeholder"
                }}</span>
            </div>
          {{else}}
            <article
              class="nested-post__article boxed"
              data-post-id={{@post.id}}
              data-post-number={{@post.post_number}}
              {{@registerPost @post trackOnly=true}}
            >
              <div class="nested-post__header">
                {{#if this.isMobile}}
                  <PostAvatar @post={{@post}} @size="small" />
                {{/if}}
                <PostMetaData
                  @post={{@post}}
                  @editPost={{@editPost}}
                  @showHistory={{fn @showHistory @post}}
                />
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
              <div class="nested-post__content">
                <PostCookedHtml @post={{@post}} />
              </div>
              <section class="nested-post__menu post-menu-area clearfix">
                <PostMenu
                  @post={{@post}}
                  @canCreatePost={{this.canCreatePost}}
                  @copyLink={{this.copyLink}}
                  @deletePost={{fn @deletePost @post}}
                  @editPost={{fn @editPost @post}}
                  @recoverPost={{fn @recoverPost @post}}
                  @replyToPost={{fn @replyToPost @post @depth}}
                  @share={{this.share}}
                  @showFlags={{fn @showFlags @post}}
                  @toggleLike={{this.toggleLike}}
                  @toggleReplies={{unless this.atMaxDepth this.toggleExpanded}}
                  @repliesShown={{if this.atMaxDepth true this.expanded}}
                  @showLogin={{this.showLogin}}
                />
              </section>
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
          {{/if}}

          {{#if (and this.expanded (not this.collapsed) (not this.atMaxDepth))}}
            <NestedPostChildren
              @topic={{@topic}}
              @parentPostNumber={{@post.post_number}}
              @preloadedChildren={{@children}}
              @directReplyCount={{@post.direct_reply_count}}
              @totalDescendantCount={{@post.total_descendant_count}}
              @depth={{@depth}}
              @sort={{@sort}}
              @defaultCollapsed={{@defaultCollapsed}}
              @replyToPost={{@replyToPost}}
              @editPost={{@editPost}}
              @deletePost={{@deletePost}}
              @recoverPost={{@recoverPost}}
              @showFlags={{@showFlags}}
              @showHistory={{@showHistory}}
              @collapseParent={{this.toggleExpanded}}
              @highlightParentLine={{this.highlightLine}}
              @unhighlightParentLine={{this.unhighlightLine}}
              @parentLineHighlighted={{this.lineHighlighted}}
              @expansionState={{@expansionState}}
              @fetchedChildrenCache={{@fetchedChildrenCache}}
              @scrollAnchor={{@scrollAnchor}}
              @registerPost={{@registerPost}}
            />
          {{/if}}
        </div>
      {{/unless}}
    </div>
  </template>
}
