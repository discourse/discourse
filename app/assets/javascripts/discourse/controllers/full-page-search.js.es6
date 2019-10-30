import { or } from "@ember/object/computed";
import { inject } from "@ember/controller";
import Controller from "@ember/controller";
import { ajax } from "discourse/lib/ajax";
import {
  translateResults,
  searchContextDescription,
  getSearchKey,
  isValidSearchTerm
} from "discourse/lib/search";
import {
  default as computed,
  observes
} from "ember-addons/ember-computed-decorators";
import Category from "discourse/models/category";
import { escapeExpression } from "discourse/lib/utilities";
import { setTransient } from "discourse/lib/page-tracker";
import { iconHTML } from "discourse-common/lib/icon-library";
import Composer from "discourse/models/composer";
import { scrollTop } from "discourse/mixins/scroll-top";

const SortOrders = [
  { name: I18n.t("search.relevance"), id: 0 },
  { name: I18n.t("search.latest_post"), id: 1, term: "order:latest" },
  { name: I18n.t("search.most_liked"), id: 2, term: "order:likes" },
  { name: I18n.t("search.most_viewed"), id: 3, term: "order:views" },
  { name: I18n.t("search.latest_topic"), id: 4, term: "order:latest_topic" }
];
const PAGE_LIMIT = 10;

export default Controller.extend({
  application: inject(),
  composer: inject(),
  bulkSelectEnabled: null,

  loading: false,
  queryParams: ["q", "expanded", "context_id", "context", "skip_context"],
  q: null,
  selected: [],
  expanded: false,
  context_id: null,
  context: null,
  searching: false,
  sortOrder: 0,
  sortOrders: SortOrders,
  invalidSearch: false,
  page: 1,
  resultCount: null,

  @computed("resultCount")
  hasResults(resultCount) {
    return (resultCount || 0) > 0;
  },

  @computed("q")
  hasAutofocus(q) {
    return Ember.isEmpty(q);
  },

  @computed("q")
  highlightQuery(q) {
    if (!q) {
      return;
    }
    // remove l which can be used for sorting
    return _.reject(q.split(/\s+/), t => t === "l").join(" ");
  },

  @computed("skip_context", "context")
  searchContextEnabled: {
    get(skip, context) {
      return (!skip && context) || skip === "false";
    },
    set(val) {
      this.set("skip_context", val ? "false" : "true");
    }
  },

  @computed("context", "context_id")
  searchContextDescription(context, id) {
    var name = id;
    if (context === "category") {
      var category = Category.findById(id);
      if (!category) {
        return;
      }

      name = category.get("name");
    }
    return searchContextDescription(context, name);
  },

  @computed("q")
  searchActive(q) {
    return isValidSearchTerm(q);
  },

  @computed("q")
  noSortQ(q) {
    q = this.cleanTerm(q);
    return escapeExpression(q);
  },

  @computed("canCreateTopic", "siteSettings.login_required")
  showSuggestion(canCreateTopic, loginRequired) {
    return canCreateTopic || !loginRequired;
  },

  _searchOnSortChange: true,

  setSearchTerm(term) {
    this._searchOnSortChange = false;
    term = this.cleanTerm(term);
    this._searchOnSortChange = true;
    this.set("searchTerm", term);
  },

  cleanTerm(term) {
    if (term) {
      SortOrders.forEach(order => {
        if (order.term) {
          let matches = term.match(new RegExp(`${order.term}\\b`));
          if (matches) {
            this.set("sortOrder", order.id);
            term = term.replace(new RegExp(`${order.term}\\b`, "g"), "");
            term = term.trim();
          }
        }
      });
    }
    return term;
  },

  @observes("sortOrder")
  triggerSearch() {
    if (this._searchOnSortChange) {
      this.set("page", 1);
      this._search();
    }
  },

  @observes("model")
  modelChanged() {
    if (this.searchTerm !== this.q) {
      this.setSearchTerm(this.q);
    }
  },

  @computed("q")
  showLikeCount(q) {
    return q && q.indexOf("order:likes") > -1;
  },

  @observes("q")
  qChanged() {
    const model = this.model;
    if (model && this.get("model.q") !== this.q) {
      this.setSearchTerm(this.q);
      this.send("search");
    }
  },

  @computed("q")
  isPrivateMessage(q) {
    return (
      q &&
      this.currentUser &&
      (q.indexOf("in:personal") > -1 ||
        q.indexOf(
          `personal_messages:${this.currentUser.get("username_lower")}`
        ) > -1)
    );
  },

  @observes("loading")
  _showFooter() {
    this.set("application.showFooter", !this.loading);
  },

  @computed("resultCount", "noSortQ")
  resultCountLabel(count, term) {
    const plus = count % 50 === 0 ? "+" : "";
    return I18n.t("search.result_count", { count, plus, term });
  },

  @observes("model.posts.length")
  resultCountChanged() {
    this.set("resultCount", this.get("model.posts.length"));
  },

  @computed("hasResults")
  canBulkSelect(hasResults) {
    return this.currentUser && this.currentUser.staff && hasResults;
  },

  @computed("model.grouped_search_result.can_create_topic")
  canCreateTopic(userCanCreateTopic) {
    return this.currentUser && userCanCreateTopic;
  },

  @computed("expanded")
  searchAdvancedIcon(expanded) {
    return iconHTML(expanded ? "caret-down" : "caret-right");
  },

  @computed("page")
  isLastPage(page) {
    return page === PAGE_LIMIT;
  },

  searchButtonDisabled: or("searching", "loading"),

  _search() {
    if (this.searching) {
      return;
    }

    this.set("invalidSearch", false);
    const searchTerm = this.searchTerm;
    if (!isValidSearchTerm(searchTerm)) {
      this.set("invalidSearch", true);
      return;
    }

    let args = { q: searchTerm, page: this.page };

    if (args.page === 1) {
      this.set("bulkSelectEnabled", false);
      this.selected.clear();
      this.set("searching", true);
      scrollTop();
    } else {
      this.set("loading", true);
    }

    const sortOrder = this.sortOrder;
    if (sortOrder && SortOrders[sortOrder].term) {
      args.q += " " + SortOrders[sortOrder].term;
    }

    this.set("q", args.q);

    const skip = this.skip_context;
    if ((!skip && this.context) || skip === "false") {
      args.search_context = {
        type: this.context,
        id: this.context_id
      };
    }

    const searchKey = getSearchKey(args);

    ajax("/search", { data: args })
      .then(results => {
        const model = translateResults(results) || {};

        if (results.grouped_search_result) {
          this.set("q", results.grouped_search_result.term);
        }

        if (args.page > 1) {
          if (model) {
            this.model.posts.pushObjects(model.posts);
            this.model.topics.pushObjects(model.topics);
            this.model.set(
              "grouped_search_result",
              results.grouped_search_result
            );
          }
        } else {
          setTransient("lastSearch", { searchKey, model }, 5);
          model.grouped_search_result = results.grouped_search_result;
          this.set("model", model);
        }
      })
      .finally(() => {
        this.set("searching", false);
        this.set("loading", false);
      });
  },

  actions: {
    createTopic(searchTerm) {
      let topicCategory;
      if (searchTerm.indexOf("category:") !== -1) {
        const match = searchTerm.match(/category:(\S*)/);
        if (match && match[1]) {
          topicCategory = match[1];
        }
      }
      this.composer.open({
        action: Composer.CREATE_TOPIC,
        draftKey: Composer.NEW_TOPIC_KEY,
        topicCategory
      });
    },

    selectAll() {
      this.selected.addObjects(this.get("model.posts").map(r => r.topic));
      // Doing this the proper way is a HUGE pain,
      // we can hack this to work by observing each on the array
      // in the component, however, when we select ANYTHING, we would force
      // 50 traversals of the list
      // This hack is cheap and easy
      $(".fps-result input[type=checkbox]").prop("checked", true);
    },

    clearAll() {
      this.selected.clear();
      $(".fps-result input[type=checkbox]").prop("checked", false);
    },

    toggleBulkSelect() {
      this.toggleProperty("bulkSelectEnabled");
      this.selected.clear();
    },

    search() {
      this.set("page", 1);
      this._search();
      if (this.site.mobileView) this.set("expanded", false);
    },

    toggleAdvancedSearch() {
      this.toggleProperty("expanded");
    },

    loadMore() {
      var page = this.page;
      if (
        this.get("model.grouped_search_result.more_full_page_results") &&
        !this.loading &&
        page < PAGE_LIMIT
      ) {
        this.incrementProperty("page");
        this._search();
      }
    },

    logClick(topicId) {
      if (this.get("model.grouped_search_result.search_log_id") && topicId) {
        ajax("/search/click", {
          type: "POST",
          data: {
            search_log_id: this.get(
              "model.grouped_search_result.search_log_id"
            ),
            search_result_id: topicId,
            search_result_type: "topic"
          }
        });
      }
    }
  }
});
