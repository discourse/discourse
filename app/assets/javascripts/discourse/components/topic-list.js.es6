import { observes } from "ember-addons/ember-computed-decorators";

export default Ember.Component.extend({
  tagName: "table",
  classNames: ["topic-list"],
  showTopicPostBadges: true,
  listTitle: "topic.title",

  // Overwrite this to perform client side filtering of topics, if desired
  filteredTopics: Ember.computed.alias("topics"),

  _init: function() {
    this.addObserver("hideCategory", this.rerender);
    this.addObserver("order", this.rerender);
    this.addObserver("ascending", this.rerender);
    this.refreshLastVisited();
  }.on("init"),

  toggleInTitle: function() {
    return !this.get("bulkSelectEnabled") && this.get("canBulkSelect");
  }.property("bulkSelectEnabled"),

  sortable: function() {
    return !!this.get("changeSort");
  }.property(),

  skipHeader: function() {
    return this.site.mobileView;
  }.property(),

  showLikes: function() {
    return this.get("order") === "likes";
  }.property("order"),

  showOpLikes: function() {
    return this.get("order") === "op_likes";
  }.property("order"),

  @observes("topics.[]")
  topicsAdded() {
    // special case so we don't keep scanning huge lists
    if (!this.get("lastVisitedTopic")) {
      this.refreshLastVisited();
    }
  },

  @observes("topics", "order", "ascending", "category", "top")
  lastVisitedTopicChanged() {
    this.refreshLastVisited();
  },

  _updateLastVisitedTopic(topics, order, ascending, top) {
    this.set("lastVisitedTopic", null);

    if (!this.get("highlightLastVisited")) {
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
      this.get("topics"),
      this.get("order"),
      this.get("ascending"),
      this.get("top")
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
