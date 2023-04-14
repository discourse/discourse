/* eslint-disable no-console */
import { alias, and } from "@ember/object/computed";
import discourseComputed, { observes } from "discourse-common/utils/decorators";
import Component from "@ember/component";
import LoadMore from "discourse/mixins/load-more";
import { on } from "@ember/object/evented";
import { next, schedule } from "@ember/runloop";
import showModal from "discourse/lib/show-modal";
// import { ajax } from "discourse/lib/ajax";

export default Component.extend(LoadMore, {
  tagName: "table",
  classNames: ["topic-list"],
  classNameBindings: ["bulkSelectEnabled:sticky-header"],
  showTopicPostBadges: true,
  showUserVoiceCredits: false,
  showQuadraticTotals: false,
  listTitle: "topic.title",
  canDoBulkActions: and("currentUser.canManageTopic", "selected.length"),
  // Overwrite this to perform client side filtering of topics, if desired
  filteredTopics: alias("topics"),
  topicVotes: {},

  fetchTopicVotes() {
    const categoryId = this.get("category.id");
    const url = `/topics/category-totals/${categoryId}.json`;

    fetch(url, {
      headers: {
        "Access-Control-Request-Headers": "*",
        "Access-Control-Allow-Methods": "GET",
      },
    })
      .then((response) => response.json())
      .then((r) => {
        if (r.success) {
          console.log("topicVotes", r.total_vote_values_per_topic);
          this.set("topicVotes", r.total_vote_values_per_topic);
          this.set("showQuadraticTotals", true);
        }
      })
      .catch((error) => {
        console.error("Error fetching quadratic_votes:", error);
      });
  },

  fetchUserVoiceCredits() {
    const categoryId = this.get("category.id");
    const url = `/voice_credits.json?category_id=${categoryId}`;
    return fetch(url, {
      headers: {
        "Access-Control-Request-Headers": "*",
        "Access-Control-Allow-Methods": "GET",
      },
    })
      .then(function (response) {
        return response.json();
      })
      .then((r) => {
        if (r.success) {
          console.log("r.success", r.voice_credits_by_topic_id);
          this.set("voiceCredits", r.voice_credits_by_topic_id);
        }
      })
      .catch(function (error) {
        let message;
        if (error.hasOwnProperty("message")) {
          message = error.message;
        } else {
          message = error;
        }
        console.log(message);
      });
  },

  _init: on("init", function () {
    if (this.category && this.category.id) {
      this.fetchTopicVotes(this.category.id);
      if (this.currentUser) {
        this.fetchUserVoiceCredits();
      }
    }
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
    if (!onScroll) {
      return;
    }

    onScroll.call(this);
  },

  scrollToLastPosition() {
    if (!this.scrollOnLoad) {
      return;
    }

    const scrollTo = this.session.topicListScrollPosition;
    if (scrollTo >= 0) {
      schedule("afterRender", () => {
        if (this.element && !this.isDestroying && !this.isDestroyed) {
          next(() => window.scrollTo(0, scrollTo));
        }
      });
    }
  },

  didInsertElement() {
    this._super(...arguments);
    this.scrollToLastPosition();
    if (this.currentUser && this.category && this.category.id) {
      this.set("showUserVoiceCredits", true);
    }
  },

  didUpdateAttrs() {
    this._super(...arguments);
  },
  /*

  voteComment() {

    const payload =
       {
          category_id: 6,
          voice_credits_data:
          [
             { topic_id: 18, credits_allocated: 16 },
             { topic_id: 19, credits_allocated: 25 },
             { topic_id: 34, credits_allocated: 36  },
             { topic_id: 35, credits_allocated: 4  },
          ]
         };
    return ajax("/voice_credits.json", {
      type: "POST",
      data: payload,
    })
      .then((r) => {
       //debugger;
      })
      .catch(function (error) {
        //debugger;
        // eslint-disable-next-line no-console
        console.log(error);
      });
  },
  */

  /*
   */

  _updateLastVisitedTopic(topics, order, ascending, top) {
    this.set("lastVisitedTopic", null);

    if (!this.highlightLastVisited) {
      return;
    }

    if (order && order !== "activity") {
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

  updateAutoAddTopicsToBulkSelect(newVal) {
    this.set("autoAddTopicsToBulkSelect", newVal);
  },

  click(e) {
    const onClick = (sel, callback) => {
      let target = e.target.closest(sel);

      if (target) {
        callback.call(this, target);
      }
    };

    onClick("button.bulk-select", function () {
      this.toggleBulkSelect();
      this.rerender();
    });

    onClick("button.bulk-select-all", function () {
      this.updateAutoAddTopicsToBulkSelect(true);
      document
        .querySelectorAll("input.bulk-select:not(:checked)")
        .forEach((el) => el.click());
    });

    onClick("button.bulk-clear-all", function () {
      this.updateAutoAddTopicsToBulkSelect(false);
      document
        .querySelectorAll("input.bulk-select:checked")
        .forEach((el) => el.click());
    });

    onClick("th.sortable", function (element) {
      this.changeSort(element.dataset.sortOrder);
      this.rerender();
    });

    onClick("button.bulk-select-actions", function () {
      const controller = showModal("topic-bulk-actions", {
        model: {
          topics: this.selected,
          category: this.category,
        },
        title: "topics.bulk.actions",
      });

      const action = this.bulkSelectAction;
      if (action) {
        controller.set("refreshClosure", () => action());
      }
    });
  },

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
  },
});
