import { alias, reads } from "@ember/object/computed";
import { schedule } from "@ember/runloop";
import Component from "@ember/component";
import discourseComputed, { observes } from "discourse-common/utils/decorators";
import LoadMore from "discourse/mixins/load-more";
import { on } from "@ember/object/evented";

export default Component.extend(LoadMore, {
  tagName: "table",
  classNames: ["topic-list"],
  showTopicPostBadges: true,
  listTitle: "topic.title",

  // Overwrite this to perform client side filtering of topics, if desired
  filteredTopics: alias("topics"),

  _init: on("init", function() {
    this.addObserver("hideCategory", this.rerender);
    this.addObserver("order", this.rerender);
    this.addObserver("ascending", this.rerender);
    this.refreshLastVisited();
  }),

  @discourseComputed("bulkSelectEnabled")
  toggleInTitle(bulkSelectEnabled) {
    return !bulkSelectEnabled && this.canBulkSelect;
  },

  @discourseComputed
  sortable() {
    return !!this.changeSort;
  },

  skipHeader: reads("site.mobileView"),

  @discourseComputed("order")
  showLikes(order) {
    return order === "likes";
  },

  @discourseComputed("order")
  showOpLikes(order) {
    return order === "op_likes";
  },

  @observes("topics.[]")
  topicsAdded() {
    // special case so we don't keep scanning huge lists
    if (!this.lastVisitedTopic) {
      this.refreshLastVisited();
    }
  },

  @observes("topics", "order", "ascending", "category", "top")
  lastVisitedTopicChanged() {
    this.refreshLastVisited();
  },

  scrolled() {
    this._super(...arguments);
    let onScroll = this.onScroll;
    if (!onScroll) return;

    onScroll.call(this);
  },

  scrollToLastPosition() {
    if (!this.scrollOnLoad) return;

    let scrollTo = this.session.get("topicListScrollPosition");
    if (scrollTo && scrollTo >= 0) {
      schedule("afterRender", () => $(window).scrollTop(scrollTo + 1));
    }
  },

  didInsertElement() {
    this._super(...arguments);
    this.scrollToLastPosition();
  },

  _updateLastVisitedTopic(topics, order, ascending, top) {
    this.set("lastVisitedTopic", null);

    if (!this.highlightLastVisited) {
      return;
    }

    if (order !== "default" && order !== "activity") {
      return;
    }

    if (top) {
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
  },

  refreshLastVisited() {
    this._updateLastVisitedTopic(
      this.topics,
      this.order,
      this.ascending,
      this.top
    );
  },

  click(e) {
    var self = this;
    var onClick = function(sel, callback) {
      var target = $(e.target).closest(sel);

      if (target.length === 1) {
        callback.apply(self, [target]);
      }
    };

    onClick("button.bulk-select", function() {
      this.toggleBulkSelect();
      this.rerender();
    });

    onClick("button.bulk-select-all", function() {
      $("input.bulk-select:not(:checked)").click();
    });

    onClick("button.bulk-clear-all", function() {
      $("input.bulk-select:checked").click();
    });

    onClick("th.sortable", function(e2) {
      this.changeSort(e2.data("sort-order"));
      this.rerender();
    });
  }
});
