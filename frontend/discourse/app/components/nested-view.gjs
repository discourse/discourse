import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import ConditionalLoadingSpinner from "discourse/components/conditional-loading-spinner";
import DButton from "discourse/components/d-button";
import LoadMore from "discourse/components/load-more";
import TopicMap from "discourse/components/topic-map";
import getURL from "discourse/lib/get-url";
import PostStreamViewportTracker from "discourse/modifiers/post-stream-viewport-tracker";
import { eq, gt } from "discourse/truth-helpers";
import { i18n } from "discourse-i18n";
import NestedFloatingActions from "./nested-floating-actions";
import NestedOp from "./nested-op";
import NestedPost from "./nested-post";
import NestedSortSelector from "./nested-sort-selector";
import NestedViewHeader from "./nested-view-header";

export default class NestedView extends Component {
  @service header;
  @service screenTrack;

  @tracked cloakAbove = 0;
  @tracked cloakBelow = 0;
  viewportTracker = new PostStreamViewportTracker();

  // Core's TopicMap requires a @postStream arg for flat-view features
  // (filtering by participant, "Top Replies" toggle). The nested view has
  // no PostStream, so we supply a stub that satisfies the interface with
  // safe no-ops. The "Top Replies" button is hidden via CSS.
  postStreamStub = {
    summary: false,
    loadingFilter: false,
    userFilters: [],
    showTopReplies() {},
    cancelFilter() {},
    refresh() {},
  };

  willDestroy() {
    super.willDestroy(...arguments);
    this.viewportTracker.destroy();
  }

  get flatViewUrl() {
    return getURL(`/t/${this.args.topic.slug}/${this.args.topic.id}?flat=1`);
  }

  @action
  setCloakingBoundaries(above, below) {
    this.cloakAbove = above;
    this.cloakBelow = below;
  }

  <template>
    <div
      class="nested-view"
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
        @replyToPost={{@replyToPost}}
        @showPostMenu={{true}}
        @registerPost={{this.viewportTracker.registerPost}}
      />

      <div class="nested-view__topic-map topic-map">
        <TopicMap
          @model={{@topic}}
          @topicDetails={{@topic.details}}
          @postStream={{this.postStreamStub}}
          @showPMMap={{@topic.isPrivateMessage}}
        />
      </div>

      <div class="nested-view__controls">
        <NestedSortSelector @current={{@sort}} @onChange={{@changeSort}} />
        <a href={{this.flatViewUrl}} class="nested-view__flat-link">{{i18n
            "nested_replies.view_as_flat"
          }}</a>
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
        {{#each @rootNodes as |node|}}
          <NestedPost
            @post={{node.post}}
            @children={{node.children}}
            @topic={{@topic}}
            @depth={{0}}
            @sort={{@sort}}
            @isPinned={{eq node.post.post_number @pinnedPostNumber}}
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
        {{else}}
          <div class="nested-view__empty">
            {{i18n "nested_replies.no_replies"}}
          </div>
        {{/each}}
      </div>

      <ConditionalLoadingSpinner @condition={{@loadingMore}} />

      <LoadMore
        @action={{@loadMoreRoots}}
        @enabled={{@hasMoreRoots}}
        @isLoading={{@loadingMore}}
      />

      <NestedFloatingActions
        @topic={{@topic}}
        @replyAction={{fn @replyToPost @opPost 0}}
      />
    </div>
  </template>
}
