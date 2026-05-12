import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { array, fn } from "@ember/helper";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import { cancel, next, schedule } from "@ember/runloop";
import { service } from "@ember/service";
import MoreTopics from "discourse/components/more-topics";
import PluginOutlet from "discourse/components/plugin-outlet";
import lazyHash from "discourse/helpers/lazy-hash";
import getURL from "discourse/lib/get-url";
import PostStreamViewportTracker from "discourse/modifiers/post-stream-viewport-tracker";
import { or } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";
import NestedFloatingActions from "./floating-actions";
import NestedHeader from "./header";
import NestedOp from "./op";
import NestedPost from "./post";
import NestedSortSelector from "./sort-selector";

export default class NestedContextView extends Component {
  @service appEvents;
  @service currentUser;
  @service header;
  @service screenTrack;

  @tracked cloakAbove = 0;
  @tracked cloakBelow = 0;
  viewportTracker = new PostStreamViewportTracker();
  #scrollAttempts = 0;
  #maxScrollAttempts = 20;
  #destroyed = false;
  #nextTimer = null;
  #retryTimer = null;
  #highlightTimer = null;

  constructor() {
    super(...arguments);
    this.appEvents.on("nested:scroll-to-target", this, this.scheduleScroll);
  }

  willDestroy() {
    super.willDestroy(...arguments);
    this.#destroyed = true;
    cancel(this.#nextTimer);
    cancel(this.#retryTimer);
    clearTimeout(this.#highlightTimer);
    this.appEvents.off("nested:scroll-to-target", this, this.scheduleScroll);
    this.viewportTracker.destroy();
  }

  // next() runs after RouteScrollManager's own next() callback, so our
  // scroll wins. Fresh attempt counter per invocation.
  @action
  scheduleScroll() {
    cancel(this.#nextTimer);
    cancel(this.#retryTimer);
    clearTimeout(this.#highlightTimer);
    this.#scrollAttempts = 0;
    this.#nextTimer = next(this, this.#scrollToTarget);
  }

  get flatViewUrl() {
    return getURL(`/t/${this.args.topic.slug}/${this.args.topic.id}?flat=1`);
  }

  #scrollToTarget() {
    if (this.#destroyed) {
      return;
    }

    const postNumber = this.args.targetPostNumber;
    if (!postNumber) {
      return;
    }

    const target = document.querySelector(
      `.nested-context-view [data-post-number="${postNumber}"]`
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
      target.scrollIntoView({ behavior: "smooth", block: "center" });
    } else if (this.#scrollAttempts < this.#maxScrollAttempts) {
      // Target may not be in the DOM yet (async child rendering).
      this.#scrollAttempts++;
      this.#retryTimer = schedule("afterRender", this, this.#scrollToTarget);
    }
  }

  @action
  setCloakingBoundaries(above, below) {
    this.cloakAbove = above;
    this.cloakBelow = below;
  }

  // Only collapse when the chain is just the target — otherwise the target
  // is the chain leaf and collapsing would hide the very thing the context
  // view exists to surface.
  get effectiveCollapseFromDepth() {
    if (!this.args.collapseReplies) {
      return null;
    }
    const chainRootPostNumber = this.args.contextChain?.post?.post_number;
    if (chainRootPostNumber !== this.args.targetPostNumber) {
      return null;
    }
    return 1;
  }

  <template>
    <div
      class="nested-view nested-context-view"
      {{didInsert this.scheduleScroll}}
      {{didUpdate this.scheduleScroll @targetPostNumber @contextChain.post.id}}
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

      <NestedOp
        @post={{@opPost}}
        @topic={{@topic}}
        @editPost={{@editPost}}
        @showHistory={{@showHistory}}
        @registerPost={{this.viewportTracker.registerPost}}
      />

      <div class="nested-view__controls">
        <NestedSortSelector @current={{@sort}} @onChange={{@changeSort}} />
        <div class="nested-view__controls-right">
          {{#if @topic.has_activity_log}}
            <DButton
              class="btn-flat nested-view__activity-link"
              @action={{@showActivityLog}}
              @label="nested_replies.activity_log.link"
            />
          {{/if}}
          {{#if this.currentUser.can_toggle_nested_mode}}
            <DButton
              class="btn-flat nested-view__flat-link"
              @href={{this.flatViewUrl}}
              @label="nested_replies.view_as_flat"
            />
          {{/if}}
        </div>
      </div>

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
            @translatedLabel={{i18n "nested_replies.context.view_full_topic"}}
          />
          {{#if (or @contextNoAncestors @ancestorsTruncated)}}
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

      {{#if @contextChain}}
        <div class="nested-context-view__chain">
          {{! _renderKey changes every fetch — forces NestedPost rebuild
              when chains share a root. See routes/nested.js. }}
          {{#each (array @contextChain) key="_renderKey" as |chainRoot|}}
            <NestedPost
              @post={{chainRoot.post}}
              @children={{chainRoot.children}}
              @topic={{@topic}}
              @depth={{0}}
              @sort={{@sort}}
              @replyToPost={{@replyToPost}}
              @editPost={{@editPost}}
              @deletePost={{@deletePost}}
              @recoverPost={{@recoverPost}}
              @showFlags={{@showFlags}}
              @showHistory={{@showHistory}}
              @expansionState={{@expansionState}}
              @fetchedChildrenCache={{@fetchedChildrenCache}}
              @scrollAnchor={{@scrollAnchor}}
              @registerPost={{this.viewportTracker.registerPost}}
              @getCloakingData={{this.viewportTracker.getCloakingData}}
              @cloakAbove={{this.cloakAbove}}
              @cloakBelow={{this.cloakBelow}}
              @collapseFromDepth={{this.effectiveCollapseFromDepth}}
            />
          {{/each}}
        </div>
      {{/if}}

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

      <NestedFloatingActions
        @topic={{@topic}}
        @replyAction={{fn @replyToPost @opPost 0}}
      />
    </div>
  </template>
}
