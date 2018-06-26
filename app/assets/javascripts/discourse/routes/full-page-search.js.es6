import { ajax } from "discourse/lib/ajax";
import {
  translateResults,
  getSearchKey,
  isValidSearchTerm
} from "discourse/lib/search";
import PreloadStore from "preload-store";
import { getTransient, setTransient } from "discourse/lib/page-tracker";
import { escapeExpression } from "discourse/lib/utilities";

export default Discourse.Route.extend({
  queryParams: {
    q: {},
    expanded: false,
    context_id: {},
    context: {},
    skip_context: {}
  },

  titleToken() {
    return I18n.t("search.results_page", {
      term: escapeExpression(
        this.controllerFor("full-page-search").get("searchTerm")
      )
    });
  },

  model(params) {
    const cached = getTransient("lastSearch");
    var args = { q: params.q };
    if (params.context_id && !args.skip_context) {
      args.search_context = {
        type: params.context,
        id: params.context_id
      };
    }

    const searchKey = getSearchKey(args);

    if (cached && cached.data.searchKey === searchKey) {
      // extend expiry
      setTransient("lastSearch", { searchKey, model: cached.data.model }, 5);
      return cached.data.model;
    }

    return PreloadStore.getAndRemove("search", function() {
      if (isValidSearchTerm(params.q)) {
        return ajax("/search", { data: args });
      } else {
        return null;
      }
    }).then(results => {
      const grouped_search_result = results
        ? results.grouped_search_result
        : {};
      const model = (results && translateResults(results)) || {
        grouped_search_result
      };
      setTransient("lastSearch", { searchKey, model }, 5);
      return model;
    });
  },

  actions: {
    didTransition() {
      this.controllerFor("full-page-search")._showFooter();
      return true;
    }
  }
});
