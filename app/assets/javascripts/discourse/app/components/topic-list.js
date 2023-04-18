/* eslint-disable no-console */
/* eslint-disable no-alert */
import { alias, and } from "@ember/object/computed";
import discourseComputed, { observes } from "discourse-common/utils/decorators";
import Component from "@ember/component";
import LoadMore from "discourse/mixins/load-more";
import { on } from "@ember/object/evented";
import { next, run, schedule } from "@ember/runloop";
import showModal from "discourse/lib/show-modal";
import { action } from "@ember/object";
import jQuery from "jquery";
import { ajax } from "discourse/lib/ajax";

export default Component.extend(LoadMore, {
  tagName: "table",
  classNames: ["topic-list"],
  classNameBindings: ["bulkSelectEnabled:sticky-header"],
  showTopicPostBadges: true,
  showUserVoiceCredits: false,
  showQuadraticTotals: false,
  remainingVotes: 0,
  listTitle: "topic.title",
  canDoBulkActions: and("currentUser.canManageTopic", "selected.length"),
  // Overwrite this to perform client side filtering of topics, if desired
  filteredTopics: alias("topics"),
  topicVotes: {},
  voiceCredits: {},

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

  updateVotesCanvas() {
    const heartsContainer = document.querySelector("#user-hearts");
    if (heartsContainer) {
      heartsContainer.innerHTML = "";
      const heartImgSrc = "/images/full-heart.png";
      const emptyHeartImgSrc = "/images/empty-heart.png";
      const heartSize = 20;
      const spacing = 2;
      const rows = 5;
      const cols = 20;
      let heartCount = 0;
      for (let i = 0; i < rows; i++) {
        for (let j = 0; j < cols; j++) {
          const heartImg = document.createElement("img");
          if (heartCount >= this.getAvailableVotes()) {
            heartImg.setAttribute("src", emptyHeartImgSrc);
          } else {
            heartImg.setAttribute("src", heartImgSrc);
          }
          heartImg.style.width = `${heartSize}px`;
          heartImg.style.height = `${heartSize}px`;
          heartImg.style.margin = `${spacing}px`;
          heartsContainer.appendChild(heartImg);
          heartCount++;
        }
      }
    } else {
      console.error("hearts-container not found");
    }
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
          const remainingVotes =
            100 -
            r.voice_credits.reduce((a, b) => {
              return a + b.credits_allocated;
            }, 0);
          this.set("remainingVotes", remainingVotes);
          this.set("voiceCredits", r.voice_credits_by_topic_id);
          this.updateVotesCanvas();
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
    this.addObserver("voiceCredits", this.rerender);
    this.refreshLastVisited();
  }),

  getAvailableVotes() {
    const allUserCredits = Object.keys(this.voiceCredits).map((key) => ({
      topic_id: Number(key),
      credits_allocated: this.voiceCredits[key].credits_allocated,
    }));
    let number =
      100 -
      allUserCredits.reduce((acc, curr) => acc + curr.credits_allocated, 0);
    this.set("remainingVotes", number);
    return number;
  },

  @action
  async saveVoiceCredits() {
    const pageCategoryId = this.get("category.id");
    const allUserCredits = Object.keys(this.voiceCredits).map((key) => ({
      topic_id: Number(key),
      credits_allocated: this.voiceCredits[key].credits_allocated,

      modified: this.voiceCredits[key].modified || false,
    }));
    // Validate that the total votes from all topics even if they are not modified is less than 100
    const totalVotes = allUserCredits.reduce(
      (acc, curr) => acc + curr.credits_allocated,
      0
    );
    if (totalVotes > 100) {
      alert(
        "Invalid vote: The total value of all user entries must be between 0 and 100."
      );
      return;
    }
    // Send to the server only the modified entries
    const allModifiedUserCredits = allUserCredits.filter(
      (credit) => credit.modified
    );
    const payload = {
      category_id: pageCategoryId,
      voice_credits_data: allModifiedUserCredits,
    };

    return ajax("/voice_credits.json", {
      type: "POST",
      data: payload,
    })
      .then((response) => response)
      .then((data) => {
        console.log(data);
        this.refreshTopicVotes();
        this.updateVotesCanvas();
      })
      .catch((error) => console.error(error));
  },

  @action
  refreshTopicVotes() {
    this.fetchUserVoiceCredits();
    this.fetchTopicVotes();
  },

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
    jQuery(window).on("load", run.bind(this, this.updateVotesCanvas));
  },

  didUpdateAttrs() {
    this._super(...arguments);
  },

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

  updateTotalVotes(topicId, newValue, operator) {
    let newTopicVotes = { ...this.topicVotes };
    if (operator === "+") {
      newTopicVotes[topicId].total_votes += 1;
    } else {
      newTopicVotes[topicId].total_votes -= 1;
    }
    this.set("topicVotes", newTopicVotes);
  },

  click(e) {
    const onClick = (sel, callback) => {
      let target = e.target.closest(sel);

      if (target) {
        callback.call(this, target);
      }
    };

    onClick(".your-hearts .triangle_up", function (element) {
      const topicId = Number(element.dataset.topicId);
      const maxSqrt = 10;
      let currentCredits = { ...this.voiceCredits };
      const currentSqrt =
        !currentCredits[topicId] ||
        !Number.isInteger(currentCredits[topicId].credits_allocated ** 0.5)
          ? 0
          : currentCredits[topicId].credits_allocated ** 0.5;
      const newValue =
        currentSqrt < maxSqrt ? (currentSqrt + 1) ** 2 : maxSqrt ** 2;
      if (!currentCredits[topicId]) {
        currentCredits[topicId] = {
          topic_id: topicId,
          credits_allocated: newValue,
          user_id: this.currentUser.id,
          category_id: this.category.id,
        };
      } else {
        currentCredits[topicId].credits_allocated = newValue;
      }
      currentCredits[topicId].modified = true;
      this.set("voiceCredits", currentCredits);
      console.log("new vote " + newValue);
      this.updateVotesCanvas();
      // Only update the total votes if the user has not reached the max
      if (currentSqrt < maxSqrt) {
        this.updateTotalVotes(topicId, newValue, "+");
      }
    });

    onClick(".your-hearts .triangle_down", function (element) {
      const topicId = Number(element.dataset.topicId);
      const minSqrt = 0;
      let currentCredits = { ...this.voiceCredits };
      const currentSqrt =
        !currentCredits[topicId] ||
        !Number.isInteger(currentCredits[topicId].credits_allocated ** 0.5)
          ? 0
          : currentCredits[topicId].credits_allocated ** 0.5;
      const newValue =
        currentSqrt > minSqrt ? (currentSqrt - 1) ** 2 : minSqrt ** 2;
      if (!currentCredits[topicId]) {
        currentCredits[topicId] = {
          topic_id: topicId,
          credits_allocated: newValue,
          user_id: this.currentUser.id,
          category_id: this.category.id,
        };
      } else {
        currentCredits[topicId].credits_allocated = newValue;
      }
      currentCredits[topicId].modified = true;
      this.set("voiceCredits", currentCredits);
      console.log("new vote " + newValue);
      this.updateVotesCanvas();
      // Only update the total votes if the user has not reached the min
      if (currentSqrt > minSqrt) {
        this.updateTotalVotes(topicId, newValue, "-");
      }
    });

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

      const bulkAction = this.bulkSelectAction;
      if (bulkAction) {
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
