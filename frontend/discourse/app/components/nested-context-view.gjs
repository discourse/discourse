import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { array, fn } from "@ember/helper";
import { action } from "@ember/object";
import { cancel, next } from "@ember/runloop";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import icon from "discourse/helpers/d-icon";
import getURL from "discourse/lib/get-url";
import PostStreamViewportTracker from "discourse/modifiers/post-stream-viewport-tracker";
import { or } from "discourse/truth-helpers";
import { i18n } from "discourse-i18n";
import NestedFloatingActions from "./nested-floating-actions";
import NestedOp from "./nested-op";
import NestedPost from "./nested-post";
import NestedSortSelector from "./nested-sort-selector";
import NestedViewHeader from "./nested-view-header";

export default class NestedContextView extends Component {
  @service currentUser;
  @service header;
  @service screenTrack;

  @tracked cloakAbove = 0;
  @tracked cloakBelow = 0;
  viewportTracker = new PostStreamViewportTracker();
  _scrollAttempts = 0;
  _maxScrollAttempts = 20; // ~1 second at 50ms intervals

  constructor() {
    super(...arguments);
    // Use next() so this runs after RouteScrollManager's next() callback,
    // which otherwise resets scroll position on route transitions.
    this._nextTimer = next(this, this._scrollToTarget);
  }

  willDestroy() {
    super.willDestroy(...arguments);
    this._destroyed = true;
    cancel(this._nextTimer);
    if (this._rafId) {
      cancelAnimationFrame(this._rafId);
    }
    this.viewportTracker.destroy();
  }

  get flatViewUrl() {
    return getURL(`/t/${this.args.topic.slug}/${this.args.topic.id}?flat=1`);
  }

  _scrollToTarget() {
    if (this._destroyed) {
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
        setTimeout(
          () => postEl.classList.remove("nested-post--highlighted"),
          2000
        );
      }
      target.scrollIntoView({ behavior: "smooth", block: "center" });
    } else if (this._scrollAttempts < this._maxScrollAttempts) {
      // Element may not be in the DOM yet (async child rendering).
      // Retry on the next animation frame.
      this._scrollAttempts++;
      this._rafId = requestAnimationFrame(() => this._scrollToTarget());
    }
  }

  @action
  setCloakingBoundaries(above, below) {
    this.cloakAbove = above;
    this.cloakBelow = below;
  }

  <template>
    <div
      class="nested-view nested-context-view"
      {{this.viewportTracker.setup
        eyeline=false
        headerOffset=this.header.headerOffset
        screenTrack=this.screenTrack
        setCloakingBoundaries=this.setCloakingBoundaries
        topicId=@topic.id
      }}
    >
      <NestedViewHeader
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
        {{#if this.currentUser.can_toggle_nested_mode}}
          <a href={{this.flatViewUrl}} class="nested-view__flat-link">{{i18n
              "nested_replies.view_as_flat"
            }}</a>
        {{/if}}
      </div>

      <div class="nested-context-view__banner">
        <span class="nested-context-view__banner-icon">{{icon
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
          {{! Use each+key to force full component recreation when the chain root changes,
              e.g. navigating from context=0 to full ancestor view }}
          {{#each (array @contextChain) key="post.id" as |chainRoot|}}
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
            />
          {{/each}}
        </div>
      {{/if}}

      <NestedFloatingActions
        @topic={{@topic}}
        @replyAction={{fn @replyToPost @opPost 0}}
      />
    </div>
  </template>
}
