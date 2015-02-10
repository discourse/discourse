export default Discourse.Route.extend({
  model: function(params, transition) {
    // Check if the URL exists on the server
    Discourse.ajax("/" + params.path, { type: 'HEAD' }).then(function() {
      transition.abort();
      Discourse.requestRefresh();
      document.location.href = "/" + params.path;
      return null;
    }).catch(function() {
      // Display 404 page
      return Discourse.ajax("/404-body", { dataType: 'html' });
    });
  }
});
