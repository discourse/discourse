export default Discourse.Route.extend({
  model: function(params) {
    return Discourse.Group.findAll().then(function(groups) {
      return groups.filterBy("type", params.type);
    });
  },

  actions: {
    newGroup: function() {
      var self = this;
      this.transitionTo("adminGroupsType", "custom").then(function() {
        var group = Discourse.Group.create({ automatic: false, visible: true });
        self.transitionTo("adminGroup", group);
      })
    }
  }
});
