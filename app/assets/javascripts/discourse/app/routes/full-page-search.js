import {
  getSearchKey,
  isValidSearchTerm,
  translateResults,
} from "discourse/lib/search";
import { getTransient, setTransient } from "discourse/lib/page-tracker";
import DiscourseRoute from "discourse/routes/discourse";
import I18n from "I18n";
import PreloadStore from "discourse/lib/preload-store";
import { ajax } from "discourse/lib/ajax";
import { escapeExpression } from "discourse/lib/utilities";
import { action } from "@ember/object";

export default DiscourseRoute.extend({
  queryParams: {
    q: {},
    expanded: false,
    context_id: {},
    context: {},
    skip_context: {},
  },
  category: null,

  titleToken() {
    return I18n.t("search.results_page", {
      term: escapeExpression(
        this.controllerFor("full-page-search").get("searchTerm")
      ),
    });
  },

  model(params) {
    const cached = getTransient("lastSearch");
    let args = { q: params.q };
    if (params.context_id && !args.skip_context) {
      args.search_context = {
        type: params.context,
        id: params.context_id,
      };
    }

    const searchKey = getSearchKey(args);

    if (cached && cached.data.searchKey === searchKey) {
      // extend expiry
      setTransient("lastSearch", { searchKey, model: cached.data.model }, 5);
      return cached.data.model;
    }

    return PreloadStore.getAndRemove("search", () => {
      if (isValidSearchTerm(params.q, this.siteSettings)) {
        return ajax("/search", { data: args });
      } else {
        return null;
      }
    }).then(async (results) => {
      const grouped_search_result = results
        ? results.grouped_search_result
        : {};
      const model = (results && (await translateResults(results))) || {
        grouped_search_result,
      };
      setTransient("lastSearch", { searchKey, model }, 5);
      return model;
    });
  },

  @action
  didTransition() {
    this.controllerFor("full-page-search")._showFooter();
    return true;
  },
});
