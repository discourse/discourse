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
  saveButtonText: "Save",
  resetButtonText: "Reset",
  isSaving: false,

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
  async resetVoiceCredits() {
    if (this.isSaving) {
      return;
    }
    const pageCategoryId = this.get("category.id");
    const allCredits = Object.keys(this.voiceCredits).map((key) => ({
      topic_id: Number(key),
      credits_allocated: 0,
      modified: false,
    }));

    const payload = {
      category_id: pageCategoryId,
      voice_credits_data: allCredits,
    };

    this.set("isSaving", true);

    return ajax("/voice_credits.json", {
      type: "POST",
      data: payload,
    })
      .then((response) => response)
      .then((data) => {
        if (data.success === true) {
          this.set("remainingVotes", 100);
          this.set("voiceCredits", allCredits);
          this.updateVotesCanvas();
          this.set("resetButtonText", "✓");
          this.fetchTopicVotes();
        } else {
          throw new Error(data);
        }
      })
      .catch((error) => {
        this.set("resetButtonText", "X");
        console.error(error);
      })
      .finally(() => {
        this.set("isSaving", false);
        let self = this;
        setTimeout(function () {
          self.set("resetButtonText", "Reset");
        }, 1000);
      });
  },

  @action
  async saveVoiceCredits() {
    if (this.isSaving) {
      return;
    }
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
      this.set("saveButtonText", "X");
      let self = this;
      setTimeout(function () {
        self.set("saveButtonText", "Save");
      }, 1000);

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

    if (allModifiedUserCredits.length === 0) {
      // act like a request is made but no changes
      this.set("saveButtonText", "✓");
      let self = this;
      setTimeout(function () {
        self.set("saveButtonText", "Save");
      }, 1000);
      return;
    }

    this.set("isSaving", true);

    return ajax("/voice_credits.json", {
      type: "POST",
      data: payload,
    })
      .then((response) => response)
      .then((data) => {
        if (data.success === true) {
          console.log(data);
          this.updateVotesCanvas();
          this.set("saveButtonText", "✓");
          this.fetchTopicVotes();
        } else {
          throw new Error(data);
        }
      })
      .catch((error) => {
        this.set("saveButtonText", "X");
        console.error(error);
      })
      .finally(() => {
        this.set("isSaving", false);
        let self = this;
        setTimeout(function () {
          self.set("saveButtonText", "Save");
        }, 1000);
      });
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

  // currently not in use, but we are keeping it in case we want to bring back total vote updates
  updateTotalVotes(topicId, newValue, operator) {
    let newTopicVotes = { ...this.topicVotes };
    if (operator === "+") {
      newTopicVotes[topicId].total_votes += 1;
    } else {
      newTopicVotes[topicId].total_votes -= 1;
    }
    this.set("topicVotes", newTopicVotes);
  },

  voteUp(element) {
    const topicId = Number(element.dataset.topicId);
    let currentCredits = { ...this.voiceCredits };
    const newValue = currentCredits[topicId]
      ? currentCredits[topicId].credits_allocated + 1
      : 1;
    if (this.remainingVotes === 0) {
      return;
    }
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
    this.updateVotesCanvas();
    // this.updateTotalVotes(topicId, newValue, "+");
  },

  voteDown(element) {
    const topicId = Number(element.dataset.topicId);
    let currentCredits = { ...this.voiceCredits };
    if (
      !currentCredits[topicId] ||
      currentCredits[topicId].credits_allocated === 0
    ) {
      return;
    }
    const newValue = currentCredits[topicId].credits_allocated - 1;
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
    this.updateVotesCanvas();
    // this.updateTotalVotes(topicId, newValue, "-");
  },

  click(e) {
    const onClick = (sel, callback) => {
      let target = e.target.closest(sel);

      if (target) {
        callback.call(this, target);
      }
    };

    onClick(".your-hearts .triangle_up", function (element) {
      this.voteUp(element);
    });

    onClick(".mobile-hearts-cell .triangle_up_container", function (element) {
      this.voteUp(element);
    });

    onClick(".your-hearts .triangle_down", function (element) {
      this.voteDown(element);
    });

    onClick(".mobile-hearts-cell .triangle_down_container", function (element) {
      this.voteDown(element);
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
