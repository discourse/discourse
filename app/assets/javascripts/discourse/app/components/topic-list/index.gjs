import Component from "@glimmer/component";
import { fn, hash } from "@ember/helper";
import { service } from "@ember/service";
import TopicBulkActions from "discourse/components/modal/topic-bulk-actions";
import PluginOutlet from "discourse/components/plugin-outlet";
import TopicListHeader from "discourse/components/topic-list/topic-list-header";
import TopicListItem from "discourse/components/topic-list/topic-list-item";
import VisitedLine from "discourse/components/topic-list/visited-line";
import concatClass from "discourse/helpers/concat-class";
// import LoadMore from "discourse/mixins/load-more";
import discourseComputed, { observes } from "discourse-common/utils/decorators";

export default class TopicList extends Component {
  // TODO: .extend(LoadMore)
  @service currentUser;
  @service modal;
  @service router;
  @service siteSettings;

  showTopicPostBadges = true;
  listTitle = "topic.title";
  lastCheckedElementId;

  constructor() {
    super(...arguments);
    this.refreshLastVisited();
  }

  get canDoBulkActions() {
    return (
      this.currentUser?.canManageTopic &&
      this.args.bulkSelectHelper?.selected.length
    );
  }

  // Overwrite this to perform client side filtering of topics, if desired
  get filteredTopics() {
    return this.topics;
  }

  get selected() {
    return this.args.bulkSelectHelper?.selected;
  }

  get bulkSelectEnabled() {
    return this.args.bulkSelectHelper?.bulkSelectEnabled;
  }

  get toggleInTitle() {
    return (
      !this.args.bulkSelectHelper?.bulkSelectEnabled &&
      this.get("canBulkSelect")
    );
  }

  get experimentalTopicBulkActionsEnabled() {
    return this.currentUser?.use_experimental_topic_bulk_actions;
  }

  get sortable() {
    return !!this.changeSort;
  }

  @discourseComputed("order")
  showLikes(order) {
    return order === "likes";
  }

  get showOpLikes() {
    return this.args.order === "op_likes";
  }

  @observes("topics.[]")
  topicsAdded() {
    // special case so we don't keep scanning huge lists
    if (!this.lastVisitedTopic) {
      this.refreshLastVisited();
    }
  }

  @observes("topics", "order", "ascending", "category", "top", "hot")
  lastVisitedTopicChanged() {
    this.refreshLastVisited();
  }

  scrolled() {
    // TODO
    // this._super(...arguments);
    let onScroll = this.onScroll;
    if (!onScroll) {
      return;
    }

    onScroll.call(this);
  }

  _updateLastVisitedTopic(topics, order, ascending, top, hot) {
    this.set("lastVisitedTopic", null);

    if (!this.highlightLastVisited) {
      return;
    }

    if (order && order !== "activity") {
      return;
    }

    if (top || hot) {
      return;
    }

    if (!topics || topics.length === 1) {
      return;
    }

    if (ascending) {
      return;
    }

    let user = this.currentUser;
    if (!user || !user.previous_visit_at) {
      return;
    }

    let lastVisitedTopic, topic;

    let prevVisit = user.get("previousVisitAt");

    // this is more efficient cause we keep appending to list
    // work backwards
    let start = 0;
    while (topics[start] && topics[start].get("pinned")) {
      start++;
    }

    let i;
    for (i = topics.length - 1; i >= start; i--) {
      if (topics[i].get("bumpedAt") > prevVisit) {
        lastVisitedTopic = topics[i];
        break;
      }
      topic = topics[i];
    }

    if (!lastVisitedTopic || !topic) {
      return;
    }

    // end of list that was scanned
    if (topic.get("bumpedAt") > prevVisit) {
      return;
    }

    this.set("lastVisitedTopic", lastVisitedTopic);
  }

  refreshLastVisited() {
    this._updateLastVisitedTopic(
      this.topics,
      this.args.order,
      this.ascending,
      this.top,
      this.hot
    );
  }

  click(e) {
    const onClick = (sel, callback) => {
      let target = e.target.closest(sel);

      if (target) {
        callback(target);
      }
    };

    onClick("button.bulk-select", () => {
      this.args.bulkSelectHelper.toggleBulkSelect();
      this.rerender();
    });

    onClick("button.bulk-select-all", () => {
      this.args.bulkSelectHelper.autoAddTopicsToBulkSelect = true;
      document
        .querySelectorAll("input.bulk-select:not(:checked)")
        .forEach((el) => el.click());
    });

    onClick("button.bulk-clear-all", () => {
      this.args.bulkSelectHelper.autoAddTopicsToBulkSelect = false;
      document
        .querySelectorAll("input.bulk-select:checked")
        .forEach((el) => el.click());
    });

    onClick("th.sortable", (element) => {
      this.changeSort(element.dataset.sortOrder);
      this.rerender();
    });

    onClick("button.bulk-select-actions", () => {
      this.modal.show(TopicBulkActions, {
        model: {
          topics: this.args.bulkSelectHelper.selected,
          category: this.category,
          refreshClosure: () => this.router.refresh(),
        },
      });
    });

    onClick("button.topics-replies-toggle", (element) => {
      if (element.classList.contains("--all")) {
        this.changeNewListSubset(null);
      } else if (element.classList.contains("--topics")) {
        this.changeNewListSubset("topics");
      } else if (element.classList.contains("--replies")) {
        this.changeNewListSubset("replies");
      }
      this.rerender();
    });
  }

  keyDown(e) {
    if (e.key === "Enter" || e.key === " ") {
      let onKeyDown = (sel, callback) => {
        let target = e.target.closest(sel);

        if (target) {
          callback.call(this, target);
        }
      };

      onKeyDown("th.sortable", (element) => {
        this.changeSort(element.dataset.sortOrder);
        this.rerender();
      });
    }
  }

  <template>
    <table
      class={{concatClass
        "topic-list"
        (if this.bulkSelectEnabled "sticky-header")
      }}
    >
      <thead class="topic-list-header">
        <TopicListHeader
          @canBulkSelect={{this.canBulkSelect}}
          @toggleInTitle={{this.toggleInTitle}}
          @hideCategory={{this.hideCategory}}
          @showPosters={{this.showPosters}}
          @showLikes={{this.showLikes}}
          @showOpLikes={{this.showOpLikes}}
          @order={{@order}}
          @ascending={{this.ascending}}
          @sortable={{this.sortable}}
          @listTitle={{this.listTitle}}
          @bulkSelectEnabled={{this.bulkSelectEnabled}}
          @bulkSelectHelper={{this.args.bulkSelectHelper}}
          @experimentalTopicBulkActionsEnabled={{this.experimentalTopicBulkActionsEnabled}}
          @canDoBulkActions={{this.canDoBulkActions}}
          @showTopicsAndRepliesToggle={{this.showTopicsAndRepliesToggle}}
          @newListSubset={{this.newListSubset}}
          @newRepliesCount={{this.newRepliesCount}}
          @newTopicsCount={{this.newTopicsCount}}
        />
      </thead>

      <PluginOutlet
        @name="before-topic-list-body"
        @outletArgs={{hash
          topics=this.topics
          selected=this.selected
          bulkSelectEnabled=this.bulkSelectEnabled
          lastVisitedTopic=this.lastVisitedTopic
          discoveryList=this.discoveryList
          hideCategory=this.hideCategory
        }}
      />

      <tbody class="topic-list-body">
        {{#each this.filteredTopics as |topic index|}}
          <TopicListItem
            @topic={{topic}}
            @bulkSelectEnabled={{this.bulkSelectEnabled}}
            @showTopicPostBadges={{this.showTopicPostBadges}}
            @hideCategory={{this.hideCategory}}
            @showPosters={{this.showPosters}}
            @showLikes={{this.showLikes}}
            @showOpLikes={{this.showOpLikes}}
            @expandGloballyPinned={{this.expandGloballyPinned}}
            @expandAllPinned={{this.expandAllPinned}}
            @lastVisitedTopic={{this.lastVisitedTopic}}
            @selected={{this.selected}}
            @lastCheckedElementId={{this.lastCheckedElementId}}
            @updateLastCheckedElementId={{fn (mut this.lastCheckedElementId)}}
            @tagsForUser={{this.tagsForUser}}
            @focusLastVisitedTopic={{this.focusLastVisitedTopic}}
            @index={{index}}
          />

          <VisitedLine
            @lastVisitedTopic={{this.lastVisitedTopic}}
            @topic={{topic}}
          />

          <PluginOutlet
            @name="after-topic-list-item"
            @outletArgs={{hash topic=topic index=index}}
            @connectorTagName="tr"
          />
        {{/each}}
      </tbody>

      <PluginOutlet
        @name="after-topic-list-body"
        @outletArgs={{hash
          topics=this.topics
          selected=this.selected
          bulkSelectEnabled=this.bulkSelectEnabled
          lastVisitedTopic=this.lastVisitedTopic
          discoveryList=this.discoveryList
          hideCategory=this.hideCategory
        }}
      />
    </table>
  </template>
}
