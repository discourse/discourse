export default Discourse.Route.extend({
  beforeModel: function() {
    this.controllerFor('directory-show').setProperties({ sort: null, asc: null });
    this.replaceWith('directory.show', 'all');
  }
});
