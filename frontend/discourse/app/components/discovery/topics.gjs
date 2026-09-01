import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DiscoveryTopicsList from "discourse/components/discovery-topics-list";
import EmptyTopicFilter from "discourse/components/empty-topic-filter";
import NewListHeaderControlsWrapper from "discourse/components/new-list-header-controls-wrapper";
import PluginOutlet from "discourse/components/plugin-outlet";
import TopicDismissButtons from "discourse/components/topic-dismiss-buttons";
import List from "discourse/components/topic-list/list";
import hideApplicationFooter from "discourse/helpers/hide-application-footer";
import lazyHash from "discourse/helpers/lazy-hash";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { filterTypeForMode } from "discourse/lib/filter-mode";
import { applyBehaviorTransformer } from "discourse/lib/transformer";
import PeriodChooser from "discourse/select-kit/components/period-chooser";
import { or } from "discourse/truth-helpers";
import DConditionalLoadingSpinner from "discourse/ui-kit/d-conditional-loading-spinner";
import DCountI18n from "discourse/ui-kit/d-count-i18n";
import DLoadMore from "discourse/ui-kit/d-load-more";
import dLoadingSpinner from "discourse/ui-kit/helpers/d-loading-spinner";

export default class DiscoveryTopics extends Component {
  @service documentTitle;
  @service currentUser;
  @service topicTrackingState;
  @service site;

  get redirectedReason() {
    return this.currentUser?.user_option.redirected_to_top?.reason;
  }

  get order() {
    return this.args.model.get("params.order");
  }

  get ascending() {
    return this.args.model.get("params.ascending") === "true";
  }

  get hasTopics() {
    return this.args.model.get("topics.length") > 0;
  }

  get allLoaded() {
    return !this.args.model.get("more_topics_url");
  }

  get latest() {
    return filterTypeForMode(this.args.model.filter) === "latest";
  }

  get top() {
    return filterTypeForMode(this.args.model.filter) === "top";
  }

  get hot() {
    return filterTypeForMode(this.args.model.filter) === "hot";
  }

  get new() {
    return filterTypeForMode(this.args.model.filter) === "new";
  }

  get unread() {
    return filterTypeForMode(this.args.model.filter) === "unread";
  }

  get showTopicsAndRepliesToggle() {
    return this.new && this.currentUser?.unified_new_enabled;
  }

  get newRepliesCount() {
    this.topicTrackingState.get("messageCount"); // Autotrack this

    if (this.currentUser?.unified_new_enabled) {
      return this.topicTrackingState.countUnread({
        categoryId: this.args.category?.id,
        noSubcategories: this.args.noSubcategories,
        tagId: this.args.tag?.id,
      });
    } else {
      return 0;
    }
  }

  get newTopicsCount() {
    this.topicTrackingState.get("messageCount"); // Autotrack this

    if (this.currentUser?.unified_new_enabled) {
      return this.topicTrackingState.countNew({
        categoryId: this.args.category?.id,
        noSubcategories: this.args.noSubcategories,
        tagId: this.args.tag?.id,
      });
    } else {
      return 0;
    }
  }

  get showTopicPostBadges() {
    return !this.new || this.currentUser?.unified_new_enabled;
  }

  get showEmptyFilterEducationInFooter() {
    const topicsLength = this.args.model.get("topics.length");

    if (!this.allLoaded || topicsLength > 0 || !this.currentUser) {
      return false;
    }

    return true;
  }

  get renderNewListHeaderControls() {
    return this.showTopicsAndRepliesToggle && !this.args.bulkSelectEnabled;
  }

  get expandGloballyPinned() {
    return !this.expandAllPinned;
  }

  get expandAllPinned() {
    return this.args.tag || this.args.category;
  }

  get showBottomDismissButtons() {
    return this.allLoaded && !this.site.mobileView;
  }

  // Show newly inserted topics
  @action
  async showInserted(event) {
    event?.preventDefault();

    if (this.args.model.loadingBefore) {
      return; // Already loading
    }

    const { topicTrackingState } = this;

    try {
      const topicIds = [...topicTrackingState.newIncoming];
      await this.args.model.loadBefore(topicIds, true);
      topicTrackingState.clearIncoming(topicIds);
    } catch (e) {
      popupAjaxError(e);
    }
  }

  @action
  loadMore() {
    applyBehaviorTransformer(
      "discovery-topic-list-load-more",
      () => {
        this.documentTitle.updateContextCount(0);
        return this.args.model
          .loadMore()
          .then(({ moreTopicsUrl, newTopics } = {}) => {
            if (
              newTopics &&
              newTopics.length &&
              this.bulkSelectHelper?.bulkSelectEnabled
            ) {
              this.bulkSelectHelper.addTopics(newTopics);
            }

            // If after loading more topics and there's another page of topics,
            // we continue loading when there's still space in the viewport for more topics
            if (
              moreTopicsUrl &&
              window.innerHeight >= document.documentElement.scrollHeight
            ) {
              this.loadMore();
            }
          });
      },
      { model: this.args.model }
    );
  }

  <template>
    {{#if @model.canLoadMore}}
      {{hideApplicationFooter}}
    {{/if}}

    {{#if this.redirectedReason}}
      <div class="alert alert-info">{{this.redirectedReason}}</div>
    {{/if}}

    {{#if @model.sharedDrafts}}
      <List
        class="shared-drafts"
        @category={{@category}}
        @discoveryList={{true}}
        @hideCategory="true"
        @listContext="discovery"
        @listTitle="shared_drafts.title"
        @top={{this.top}}
        @topics={{@model.sharedDrafts}}
      />
    {{/if}}

    <DiscoveryTopicsList
      @bulkSelectHelper={{@bulkSelectHelper}}
      @incomingCount={{this.topicTrackingState.incomingCount}}
      @model={{@model}}
    >
      {{#if this.renderNewListHeaderControls}}
        <NewListHeaderControlsWrapper
          @changeNewListSubset={{@changeNewListSubset}}
          @current={{@model.params.subset}}
          @newRepliesCount={{this.newRepliesCount}}
          @newTopicsCount={{this.newTopicsCount}}
        />
      {{/if}}
      {{#if this.top}}
        <div class="top-lists">
          <PeriodChooser
            @action={{@changePeriod}}
            @fullDay={{false}}
            @period={{@period}}
          />
        </div>
      {{else}}
        {{#if (or this.topicTrackingState.hasIncoming @model.loadingBefore)}}
          <div class="show-more {{if this.hasTopics 'has-topics'}}">
            <a
              class="alert alert-info clickable
                {{if @model.loadingBefore 'loading'}}"
              href
              tabindex="0"
              {{on "click" this.showInserted}}
            >
              <DCountI18n
                @count={{or
                  @model.loadingBefore
                  this.topicTrackingState.incomingCount
                }}
                @key="topic_count_"
                @suffix={{this.topicTrackingState.filter}}
              />
              {{#if @model.loadingBefore}}
                {{dLoadingSpinner size="small"}}
              {{/if}}
            </a>
          </div>
        {{/if}}
      {{/if}}
      <span>
        <PluginOutlet
          @connectorTagName="div"
          @name="before-topic-list"
          @outletArgs={{lazyHash category=@category tag=@tag}}
        />
      </span>

      {{#if this.hasTopics}}
        <List
          @ariaLabelledby="topic-list-heading"
          @ascending={{this.ascending}}
          @bulkSelectHelper={{@bulkSelectHelper}}
          @canBulkSelect={{@canBulkSelect}}
          @category={{@category}}
          @changeSort={{@changeSort}}
          @discoveryList={{true}}
          @expandAllPinned={{this.expandAllPinned}}
          @expandGloballyPinned={{this.expandGloballyPinned}}
          @focusLastVisitedTopic={{true}}
          @hideCategory={{@model.hideCategory}}
          @highlightLastVisited={{true}}
          @hot={{this.hot}}
          @listContext="discovery"
          @order={{this.order}}
          @showPosters={{true}}
          @showTopicPostBadges={{this.showTopicPostBadges}}
          @top={{this.top}}
          @topics={{@model.topics}}
        />

        <DLoadMore @action={{this.loadMore}} />
      {{/if}}

      <span class="after-topic-list-plugin-outlet-wrapper">
        <PluginOutlet
          @connectorTagName="div"
          @name="after-topic-list"
          @outletArgs={{lazyHash
            category=@category
            tag=@tag
            loadingMore=@model.loadingMore
            canLoadMore=@model.canLoadMore
            loadMore=this.loadMore
          }}
        />
      </span>
    </DiscoveryTopicsList>

    <footer class="topic-list-bottom">
      <DConditionalLoadingSpinner @condition={{@model.loadingMore}} />
      {{#if this.allLoaded}}
        <PluginOutlet
          @name="topic-list-bottom"
          @outletArgs={{lazyHash
            category=@category
            tag=@tag
            allLoaded=this.allLoaded
            model=@model
          }}
        >
          {{#if this.showBottomDismissButtons}}
            <TopicDismissButtons
              @dismissRead={{@dismissRead}}
              @model={{@model}}
              @position="bottom"
              @resetNew={{@resetNew}}
              @selectedTopics={{@bulkSelectHelper.selected}}
              @showDismissRead={{@showDismissRead}}
              @showNewDismissCombo={{this.showTopicsAndRepliesToggle}}
              @showResetNew={{@showResetNew}}
            />
          {{/if}}

          {{#if this.showEmptyFilterEducationInFooter}}
            <EmptyTopicFilter
              @changeNewListSubset={{@changeNewListSubset}}
              @newFilter={{this.new}}
              @newListSubset={{@model.params.subset}}
              @trackingCounts={{hash
                newTopics=this.newTopicsCount
                newReplies=this.newRepliesCount
              }}
              @unreadFilter={{this.unread}}
            />
          {{/if}}
        </PluginOutlet>
      {{/if}}
    </footer>
  </template>
}
