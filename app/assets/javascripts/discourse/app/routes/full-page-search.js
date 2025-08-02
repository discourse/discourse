import { action } from "@ember/object";
import { ajax } from "discourse/lib/ajax";
import { getTransient, setTransient } from "discourse/lib/page-tracker";
import PreloadStore from "discourse/lib/preload-store";
import {
  getSearchKey,
  isValidSearchTerm,
  translateResults,
} from "discourse/lib/search";
import { escapeExpression } from "discourse/lib/utilities";
import DiscourseRoute from "discourse/routes/discourse";
import { i18n } from "discourse-i18n";

export default class FullPageSearch extends DiscourseRoute {
  queryParams = {
    q: {},
    expanded: false,
    context_id: {},
    context: {},
    skip_context: {},
  };

  category = null;

  titleToken() {
    return i18n("search.results_page", {
      term: escapeExpression(
        this.controllerFor("full-page-search").get("searchTerm")
      ),
    });
  }

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
      const model = (results && (await translateResults(results))) || {};
      setTransient("lastSearch", { searchKey, model }, 5);
      return model;
    });
  }

  @action
  didTransition() {
    this.controllerFor("full-page-search")._afterTransition();
    return true;
  }
}
