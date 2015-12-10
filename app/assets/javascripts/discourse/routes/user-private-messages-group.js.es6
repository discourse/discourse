import createPMRoute from "discourse/routes/build-user-topic-list-route";

export default createPMRoute('groups', 'private-messages-groups').extend({
    model(params) {
      return this.store.findFiltered("topicList", { filter: "topics/private-messages-group/" + this.modelFor("user").get("username_lower") + "/" + params.name });
    },

    setupController(controller,model) {
      this._super.apply(this, arguments);
      const filter = _.last(model.get("filter").split('/'));
      this.controllerFor("user").set("groupFilter", filter);
    }
});
