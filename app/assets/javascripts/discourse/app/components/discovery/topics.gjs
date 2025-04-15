import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn, hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { or } from "truth-helpers";
import ConditionalLoadingSpinner from "discourse/components/conditional-loading-spinner";
import CountI18n from "discourse/components/count-i18n";
import DiscourseLinkedText from "discourse/components/discourse-linked-text";
import DiscoveryTopicsList from "discourse/components/discovery-topics-list";
import FooterMessage from "discourse/components/footer-message";
import NewListHeaderControlsWrapper from "discourse/components/new-list-header-controls-wrapper";
import PluginOutlet from "discourse/components/plugin-outlet";
import TopPeriodButtons from "discourse/components/top-period-buttons";
import TopicDismissButtons from "discourse/components/topic-dismiss-buttons";
import List from "discourse/components/topic-list/list";
import basePath from "discourse/helpers/base-path";
import hideApplicationFooter from "discourse/helpers/hide-application-footer";
import htmlSafe from "discourse/helpers/html-safe";
import loadingSpinner from "discourse/helpers/loading-spinner";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { filterTypeForMode } from "discourse/lib/filter-mode";
import { userPath } from "discourse/lib/url";
import { i18n } from "discourse-i18n";
import PeriodChooser from "select-kit/components/period-chooser";

export default class DiscoveryTopics extends Component {
  @service router;
  @service composer;
  @service modal;
  @service currentUser;
  @service topicTrackingState;
  @service site;

  @tracked loadingNew;

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

  get showTopicsAndRepliesToggle() {
    return this.new && this.currentUser?.new_new_view_enabled;
  }

  get newRepliesCount() {
    this.topicTrackingState.get("messageCount"); // Autotrack this

    if (this.currentUser?.new_new_view_enabled) {
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

    if (this.currentUser?.new_new_view_enabled) {
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
    return !this.new || this.currentUser?.new_new_view_enabled;
  }

  get footerMessage() {
    const topicsLength = this.args.model.get("topics.length");
    if (!this.allLoaded) {
      return;
    }

    const { category, tag } = this.args;
    if (category) {
      return i18n("topics.bottom.category", {
        category: category.get("name"),
      });
    } else if (tag) {
      return i18n("topics.bottom.tag", {
        tag: tag.id,
      });
    } else {
      const split = (this.args.model.get("filter") || "").split("/");
      if (topicsLength === 0) {
        return i18n("topics.none." + split[0], {
          category: split[1],
        });
      } else {
        return i18n("topics.bottom." + split[0], {
          category: split[1],
        });
      }
    }
  }

  get footerEducation() {
    const topicsLength = this.args.model.get("topics.length");

    if (!this.allLoaded || topicsLength > 0 || !this.currentUser) {
      return;
    }

    const segments = (this.args.model.get("filter") || "").split("/");

    let tab = segments[segments.length - 1];

    if (tab !== "new" && tab !== "unread") {
      return;
    }

    if (tab === "new" && this.currentUser.new_new_view_enabled) {
      tab = "new_new";
    }

    return i18n("topics.none.educate." + tab, {
      userPrefsUrl: userPath(
        `${this.currentUser.get("username_lower")}/preferences/tracking`
      ),
    });
  }

  get renderNewListHeaderControls() {
    return (
      this.site.mobileView &&
      this.showTopicsAndRepliesToggle &&
      !this.args.bulkSelectEnabled
    );
  }

  get expandGloballyPinned() {
    return !this.expandAllPinned;
  }

  get expandAllPinned() {
    return this.args.tag || this.args.category;
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
        @listTitle="shared_drafts.title"
        @top={{this.top}}
        @hideCategory="true"
        @category={{@category}}
        @topics={{@model.sharedDrafts}}
        @discoveryList={{true}}
        class="shared-drafts"
      />
    {{/if}}

    <DiscoveryTopicsList
      @model={{@model}}
      @incomingCount={{this.topicTrackingState.incomingCount}}
      @bulkSelectHelper={{@bulkSelectHelper}}
      @class={{if this.footerEducation "--no-topics-education"}}
    >
      {{#if this.top}}
        <div class="top-lists">
          <PeriodChooser
            @period={{@period}}
            @action={{@changePeriod}}
            @fullDay={{false}}
          />
        </div>
      {{else}}
        {{#if (or this.topicTrackingState.hasIncoming @model.loadingBefore)}}
          <div class="show-more {{if this.hasTopics 'has-topics'}}">
            <a
              tabindex="0"
              href
              {{on "click" this.showInserted}}
              class="alert alert-info clickable
                {{if @model.loadingBefore 'loading'}}"
            >
              <CountI18n
                @key="topic_count_"
                @suffix={{this.topicTrackingState.filter}}
                @count={{or
                  @model.loadingBefore
                  this.topicTrackingState.incomingCount
                }}
              />
              {{#if @model.loadingBefore}}
                {{loadingSpinner size="small"}}
              {{/if}}
            </a>
          </div>
        {{/if}}
      {{/if}}

      {{#if this.renderNewListHeaderControls}}
        <NewListHeaderControlsWrapper
          @current={{@model.params.subset}}
          @newRepliesCount={{this.newRepliesCount}}
          @newTopicsCount={{this.newTopicsCount}}
          @changeNewListSubset={{@changeNewListSubset}}
        />
      {{/if}}

      <span>
        <PluginOutlet
          @name="before-topic-list"
          @connectorTagName="div"
          @outletArgs={{hash category=@category tag=@tag}}
        />
      </span>

      {{#if this.hasTopics}}
        <List
          @highlightLastVisited={{true}}
          @top={{this.top}}
          @hot={{this.hot}}
          @showTopicPostBadges={{this.showTopicPostBadges}}
          @showPosters={{true}}
          @canBulkSelect={{@canBulkSelect}}
          @bulkSelectHelper={{@bulkSelectHelper}}
          @changeSort={{@changeSort}}
          @hideCategory={{@model.hideCategory}}
          @order={{this.order}}
          @ascending={{this.ascending}}
          @expandGloballyPinned={{this.expandGloballyPinned}}
          @expandAllPinned={{this.expandAllPinned}}
          @category={{@category}}
          @topics={{@model.topics}}
          @discoveryList={{true}}
          @focusLastVisitedTopic={{true}}
          @showTopicsAndRepliesToggle={{this.showTopicsAndRepliesToggle}}
          @newListSubset={{@model.params.subset}}
          @changeNewListSubset={{@changeNewListSubset}}
          @newRepliesCount={{this.newRepliesCount}}
          @newTopicsCount={{this.newTopicsCount}}
        />
      {{/if}}

      <span class="after-topic-list-plugin-outlet-wrapper">
        <PluginOutlet
          @name="after-topic-list"
          @connectorTagName="div"
          @outletArgs={{hash
            category=@category
            tag=@tag
            loadingMore=@model.loadingMore
            canLoadMore=@model.canLoadMore
          }}
        />
      </span>
    </DiscoveryTopicsList>

    <footer class="topic-list-bottom">
      <ConditionalLoadingSpinner @condition={{@model.loadingMore}} />
      {{#if this.allLoaded}}
        <PluginOutlet
          @name="topic-list-bottom"
          @outletArgs={{hash
            category=@category
            tag=@tag
            allLoaded=this.allLoaded
            model=@model
          }}
        >
          <TopicDismissButtons
            @position="bottom"
            @selectedTopics={{@bulkSelectHelper.selected}}
            @model={{@model}}
            @showResetNew={{@showResetNew}}
            @showDismissRead={{@showDismissRead}}
            @resetNew={{@resetNew}}
            @dismissRead={{@dismissRead}}
          />

          <FooterMessage
            @education={{this.footerEducation}}
            @message={{this.footerMessage}}
          >
            {{#if @tag}}
              {{htmlSafe
                (i18n "topic.browse_all_tags_or_latest" basePath=(basePath))
              }}
            {{else if this.latest}}
              {{#if @category.canCreateTopic}}
                <DiscourseLinkedText
                  @action={{fn
                    this.composer.openNewTopic
                    (hash category=@category)
                  }}
                  @text="topic.suggest_create_topic"
                />
              {{/if}}
            {{else if this.top}}
              {{htmlSafe
                (i18n
                  "topic.browse_all_categories_latest_or_top"
                  basePath=(basePath)
                )
              }}
              <TopPeriodButtons @period={{@period}} @action={{@changePeriod}} />
            {{else}}
              {{htmlSafe
                (i18n "topic.browse_all_categories_latest" basePath=(basePath))
              }}
            {{/if}}
          </FooterMessage>
        </PluginOutlet>
      {{/if}}
    </footer>
  </template>
}
