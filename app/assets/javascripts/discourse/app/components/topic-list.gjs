import Component from "@ember/component";
import { hash } from "@ember/helper";
import { dependentKeyCompat } from "@ember/object/compat";
import { alias } from "@ember/object/computed";
import { service } from "@ember/service";
import {
  classNameBindings,
  classNames,
  tagName,
} from "@ember-decorators/component";
import { observes, on } from "@ember-decorators/object";
import PluginOutlet from "discourse/components/plugin-outlet";
import TopicListItem from "discourse/components/topic-list-item";
import raw from "discourse/helpers/raw";
import discourseComputed from "discourse/lib/decorators";
import deprecated from "discourse/lib/deprecated";
import { RAW_TOPIC_LIST_DEPRECATION_OPTIONS } from "discourse/lib/plugin-api";
import LoadMore from "discourse/mixins/load-more";
import { i18n } from "discourse-i18n";

@tagName("table")
@classNames("topic-list")
@classNameBindings("bulkSelectEnabled:sticky-header")
export default class TopicList extends Component.extend(LoadMore) {
  static reopen() {
    deprecated(
      "Modifying topic-list with `reopen` is deprecated. Use the value transformer `topic-list-columns` and other new topic-list plugin APIs instead.",
      RAW_TOPIC_LIST_DEPRECATION_OPTIONS
    );

    return super.reopen(...arguments);
  }

  static reopenClass() {
    deprecated(
      "Modifying topic-list with `reopenClass` is deprecated. Use the value transformer `topic-list-columns` and other new topic-list plugin APIs instead.",
      RAW_TOPIC_LIST_DEPRECATION_OPTIONS
    );

    return super.reopenClass(...arguments);
  }

  @service modal;
  @service router;
  @service siteSettings;

  showTopicPostBadges = true;
  listTitle = "topic.title";
  lastCheckedElementId = null;

  // Overwrite this to perform client side filtering of topics, if desired
  @alias("topics") filteredTopics;

  get canDoBulkActions() {
    return (
      this.currentUser?.canManageTopic && this.bulkSelectHelper?.selected.length
    );
  }

  @on("init")
  _init() {
    this.addObserver("hideCategory", this.rerender);
    this.addObserver("order", this.rerender);
    this.addObserver("ascending", this.rerender);
    this.refreshLastVisited();
  }

  get selected() {
    return this.bulkSelectHelper?.selected;
  }

  // for the classNameBindings
  @dependentKeyCompat
  get bulkSelectEnabled() {
    return (
      this.get("canBulkSelect") && this.bulkSelectHelper?.bulkSelectEnabled
    );
  }

  get toggleInTitle() {
    return (
      !this.bulkSelectHelper?.bulkSelectEnabled && this.get("canBulkSelect")
    );
  }

  @discourseComputed
  sortable() {
    return !!this.changeSort;
  }

  @discourseComputed("order")
  showLikes(order) {
    return order === "likes";
  }

  @discourseComputed("order")
  showOpLikes(order) {
    return order === "op_likes";
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
    super.scrolled(...arguments);
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
      this.order,
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
      this.bulkSelectHelper.toggleBulkSelect();
      this.rerender();
    });

    onClick("button.bulk-select-all", () => {
      this.bulkSelectHelper.autoAddTopicsToBulkSelect = true;
      document
        .querySelectorAll("input.bulk-select:not(:checked)")
        .forEach((el) => el.click());
    });

    onClick("button.bulk-clear-all", () => {
      this.bulkSelectHelper.autoAddTopicsToBulkSelect = false;
      document
        .querySelectorAll("input.bulk-select:checked")
        .forEach((el) => el.click());
    });

    onClick("th.sortable", (element) => {
      this.changeSort(element.dataset.sortOrder);
      this.rerender();
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
        e.preventDefault();
        this.changeSort(element.dataset.sortOrder);
        this.rerender();
      });
    }
  }

  <template>
    <caption class="sr-only">{{i18n "sr_topic_list_caption"}}</caption>

    <thead class="topic-list-header">
      {{raw
        "topic-list-header"
        canBulkSelect=this.canBulkSelect
        toggleInTitle=this.toggleInTitle
        hideCategory=this.hideCategory
        showPosters=this.showPosters
        showLikes=this.showLikes
        showOpLikes=this.showOpLikes
        order=this.order
        ascending=this.ascending
        sortable=this.sortable
        listTitle=this.listTitle
        bulkSelectEnabled=this.bulkSelectEnabled
        bulkSelectHelper=this.bulkSelectHelper
        canDoBulkActions=this.canDoBulkActions
        showTopicsAndRepliesToggle=this.showTopicsAndRepliesToggle
        newListSubset=this.newListSubset
        newRepliesCount=this.newRepliesCount
        newTopicsCount=this.newTopicsCount
      }}
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
          @lastChecked={{this.lastChecked}}
          @tagsForUser={{this.tagsForUser}}
          @focusLastVisitedTopic={{this.focusLastVisitedTopic}}
          @index={{index}}
        />
        {{raw
          "list/visited-line"
          lastVisitedTopic=this.lastVisitedTopic
          topic=topic
        }}
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
  </template>
}
