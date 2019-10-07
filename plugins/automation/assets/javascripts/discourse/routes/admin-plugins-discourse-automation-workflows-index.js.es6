export default Discourse.Route.extend({
  controllerName: "workflows-index",

  model() {
    return Ember.RSVP.Promise.all([
      this.store.findAll("workflow"),
      this.store.findAll("workflowable")
    ]).then(function(values) {
      return {
        workflows: values[0],
        workflowables: values[1]
      };
    });
  },

  renderTemplate() {
    this.render("workflows-index");
  }
});
