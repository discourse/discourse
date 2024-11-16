import Component from "@ember/component";
import { dependentKeyCompat } from "@ember/object/compat";
import { alias } from "@ember/object/computed";
import { service } from "@ember/service";
import {
  classNameBindings,
  classNames,
  tagName,
} from "@ember-decorators/component";
import { observes, on } from "@ember-decorators/object";
import LoadMore from "discourse/mixins/load-more";
import { needsHbrTopicList } from "discourse-common/lib/raw-templates";
import discourseComputed from "discourse-common/utils/decorators";

@tagName("table")
@classNames("topic-list")
@classNameBindings("bulkSelectEnabled:sticky-header")
export default class TopicList extends Component.extend(LoadMore) {
  static reopen() {
    needsHbrTopicList(true);
    return super.reopen(...arguments);
  }

  static reopenClass() {
    needsHbrTopicList(true);
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
    return this.bulkSelectHelper?.bulkSelectEnabled;
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
        this.changeSort(element.dataset.sortOrder);
        this.rerender();
      });
    }
  }
}
