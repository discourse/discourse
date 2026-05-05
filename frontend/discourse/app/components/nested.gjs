import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import ConditionalLoadingSpinner from "discourse/components/conditional-loading-spinner";
import DButton from "discourse/components/d-button";
import LoadMore from "discourse/components/load-more";
import MoreTopics from "discourse/components/more-topics";
import PluginOutlet from "discourse/components/plugin-outlet";
import TopicMap from "discourse/components/topic-map";
import lazyHash from "discourse/helpers/lazy-hash";
import getURL from "discourse/lib/get-url";
import PostStreamViewportTracker from "discourse/modifiers/post-stream-viewport-tracker";
import { gt, includes } from "discourse/truth-helpers";
import { i18n } from "discourse-i18n";
import NestedFloatingActions from "./nested/floating-actions";
import NestedHeader from "./nested/header";
import NestedOp from "./nested/op";
import NestedPost from "./nested/post";
import NestedSortSelector from "./nested/sort-selector";

export default class Nested extends Component {
  @service currentUser;
  @service header;
  @service screenTrack;

  @tracked cloakAbove = 0;
  @tracked cloakBelow = 0;
  viewportTracker = new PostStreamViewportTracker();

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
          @showPMMap={{@topic.isPrivateMessage}}
        />
      </div>

      <div class="nested-view__controls">
        <NestedSortSelector @current={{@sort}} @onChange={{@changeSort}} />
        <div class="nested-view__controls-right">
          <DButton
            class="btn-flat nested-view__activity-link"
            @action={{@showActivityLog}}
            @label="nested_replies.activity_log.link"
          />
          {{#if this.currentUser.can_toggle_nested_mode}}
            <DButton
              class="btn-flat nested-view__flat-link"
              @href={{this.flatViewUrl}}
              @label="nested_replies.view_as_flat"
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
        {{#each @rootNodes key="post.id" as |node|}}
          <NestedPost
            @post={{node.post}}
            @children={{node.children}}
            @topic={{@topic}}
            @depth={{0}}
            @sort={{@sort}}
            @isPinned={{includes @pinnedPostIds node.post.id}}
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

      {{#unless @hasMoreRoots}}
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
      {{/unless}}

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
