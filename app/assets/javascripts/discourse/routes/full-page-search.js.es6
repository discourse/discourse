import { translateResults }  from 'discourse/lib/search-for-term';

export default Discourse.Route.extend({
  queryParams: {
    q: {
    }
  },
  model: function(params) {
    return PreloadStore.getAndRemove("search", function() {
      return Discourse.ajax('/search', {data: {q: params.q}});
    }).then(function(results){
      var model = translateResults(results) || {};
      model.q = params.q;
      return model;
    });
  }

});
