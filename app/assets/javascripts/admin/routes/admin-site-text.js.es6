export default Discourse.Route.extend({
  model: function() {
    return Discourse.SiteTextType.findAll();
  }
});
