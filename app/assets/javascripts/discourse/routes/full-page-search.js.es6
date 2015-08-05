import { translateResults } from "discourse/lib/search-for-term";

export default Discourse.Route.extend({
  queryParams: { q: {} },

  model(params) {
    return PreloadStore.getAndRemove("search", function() {
      return Discourse.ajax("/search", { data: { q: params.q } });
    }).then(results => {
      const model = translateResults(results) || {};
      model.q = params.q;
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
