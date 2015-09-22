import { translateResults, getSearchKey, isValidSearchTerm } from "discourse/lib/search";

export default Discourse.Route.extend({
  queryParams: { q: {}, context_id: {}, context: {}, skip_context: {} },

  model(params) {
    const router = Discourse.__container__.lookup('router:main');
    var cached = router.transientCache('lastSearch');
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
      router.transientCache('lastSearch', { searchKey, model: cached.data.model }, 5);
      return cached.data.model;
    }

    return PreloadStore.getAndRemove("search", function() {
      if (isValidSearchTerm(params.q)) {
        return Discourse.ajax("/search", { data: args });
      } else {
        return null;
      }
    }).then(results => {
      const model = (results && translateResults(results)) || {};
      router.transientCache('lastSearch', { searchKey, model }, 5);
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
