import createPMRoute from "discourse/routes/build-private-messages-route";

export default createPMRoute('groups', 'private-messages-groups').extend({
    model(params) {
      const username = this.modelFor("user").get("username_lower");
      return this.store.findFiltered("topicList", {
        filter: `topics/private-messages-group/${username}/${params.name}/archive`
      });
    },

    setupController(controller, model) {
      this._super.apply(this, arguments);
      const split = model.get("filter").split('/');
      const group = split[split.length-2];
      this.controllerFor("user-private-messages").set("groupFilter", group);
      this.controllerFor("user-private-messages").set("archive", true);
    }
});
