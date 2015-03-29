export default Discourse.Route.extend({
  model(params) {
    return Discourse.Group.findAll().then(function(groups) {
      return groups.filterBy("type", params.type);
    });
  },

  actions: {
    newGroup() {
      const self = this;
      this.transitionTo("adminGroupsType", "custom").then(function() {
        var group = Discourse.Group.create({ automatic: false, visible: true });
        self.transitionTo("adminGroup", group);
      });
    }
  }
});
