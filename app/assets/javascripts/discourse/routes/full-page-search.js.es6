import { translateResults } from "discourse/lib/search";

export default Discourse.Route.extend({
  queryParams: { q: {}, "context-id": {}, context: {} },

  model(params) {
    return PreloadStore.getAndRemove("search", function() {
      if (params.q && params.q.length > 2) {
        var args = { q: params.q };
        if (params.context_id && !args.skip_context) {
          args.search_context = {
            type: params.context,
            id: params.context_id
          }
        }
        return Discourse.ajax("/search", { data: args });
      } else {
        return null;
      }
    }).then(results => {
      return (results && translateResults(results)) || {};
    });
  },

  actions: {
    didTransition() {
      this.controllerFor("full-page-search")._showFooter();
      return true;
    }
  }

});
